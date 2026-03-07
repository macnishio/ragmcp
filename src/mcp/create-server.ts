import { readFile, readdir, stat } from "node:fs/promises";
import { join, relative } from "node:path";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

import type { RagService } from "../services/rag/service.js";

function toToolResult(payload: unknown): CallToolResult {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(payload, null, 2),
      },
    ],
    structuredContent: payload as Record<string, unknown>,
  };
}

export function createMcpServer(ragService: RagService): McpServer {
  const server = new McpServer({
    name: "ragmcp",
    version: "0.1.0",
  });

  server.registerTool(
    "health_check",
    {
      title: "Health Check",
      description: "Return local server health and storage paths.",
      inputSchema: z.object({}),
    },
    async (): Promise<CallToolResult> => toToolResult(ragService.getHealth()),
  );

  server.registerTool(
    "list_sources",
    {
      title: "List Sources",
      description: "List local RAG sources stored on this machine.",
      inputSchema: z.object({}),
    },
    async (): Promise<CallToolResult> => toToolResult({ sources: ragService.listSources() }),
  );

  server.registerTool(
    "create_source",
    {
      title: "Create Source",
      description: "Create a new local RAG source.",
      inputSchema: z.object({
        name: z.string().min(1).describe("Human-readable source name."),
      }),
    },
    async ({ name }: { name: string }): Promise<CallToolResult> => {
      const source = await ragService.createSource(name);
      return toToolResult(source);
    },
  );

  server.registerTool(
    "upload_text_document",
    {
      title: "Upload Text Document",
      description: "Upload one text document into a local RAG source and index it immediately.",
      inputSchema: z.object({
        sourceId: z.string().optional().describe("Existing source identifier."),
        sourceName: z.string().optional().describe("New source name if sourceId is omitted."),
        fileName: z.string().min(1).describe("Relative file name to store."),
        content: z.string().min(1).describe("UTF-8 document content."),
      }),
    },
    async ({
      sourceId,
      sourceName,
      fileName,
      content,
    }: {
      sourceId?: string;
      sourceName?: string;
      fileName: string;
      content: string;
    }): Promise<CallToolResult> => {
      let resolvedSourceId = sourceId;
      if (!resolvedSourceId) {
        if (!sourceName) {
          throw new Error("sourceName is required when sourceId is omitted");
        }
        resolvedSourceId = (await ragService.createSource(sourceName)).sourceId;
      }

      await ragService.uploadFiles(resolvedSourceId, [
        {
          name: fileName,
          content,
          encoding: "utf8",
        },
      ]);
      const sync = await ragService.syncSource(resolvedSourceId);

      return toToolResult({
        sourceId: resolvedSourceId,
        ...sync,
      });
    },
  );

  server.registerTool(
    "delete_source",
    {
      title: "Delete Source",
      description: "Delete a local RAG source and all its documents, chunks, and files.",
      inputSchema: z.object({
        sourceId: z.string().min(1).describe("Source identifier to delete."),
      }),
    },
    async ({ sourceId }: { sourceId: string }): Promise<CallToolResult> => {
      await ragService.deleteSource(sourceId);
      return toToolResult({ deleted: true, sourceId });
    },
  );

  server.registerTool(
    "rename_source",
    {
      title: "Rename Source",
      description: "Rename an existing local RAG source.",
      inputSchema: z.object({
        sourceId: z.string().min(1).describe("Source identifier to rename."),
        name: z.string().min(1).describe("New name for the source."),
      }),
    },
    async ({ sourceId, name }: { sourceId: string; name: string }): Promise<CallToolResult> => {
      const source = ragService.renameSource(sourceId, name);
      return toToolResult(source);
    },
  );

  server.registerTool(
    "search_source",
    {
      title: "Search Source",
      description: "Search a local RAG source using SQLite FTS and fallbacks.",
      inputSchema: z.object({
        sourceId: z.string().min(1),
        query: z.string().min(1),
        limit: z.number().int().min(1).max(25).default(8),
      }),
    },
    async ({
      sourceId,
      query,
      limit,
    }: {
      sourceId: string;
      query: string;
      limit: number;
    }): Promise<CallToolResult> =>
      toToolResult(ragService.searchSource(sourceId, query, limit)),
  );

  server.registerTool(
    "answer_source",
    {
      title: "Answer Source",
      description: "Return a citation-style local answer from indexed passages.",
      inputSchema: z.object({
        sourceId: z.string().min(1),
        question: z.string().min(1),
        limit: z.number().int().min(1).max(10).default(5),
      }),
    },
    async ({
      sourceId,
      question,
      limit,
    }: {
      sourceId: string;
      question: string;
      limit: number;
    }): Promise<CallToolResult> =>
      toToolResult(ragService.answerSource(sourceId, question, limit)),
  );

  server.registerTool(
    "ingest_local_folder",
    {
      title: "Ingest Local Folder",
      description:
        "Read files from a local folder path on this machine and ingest them into a RAG source. " +
        "Creates a new source if sourceName is provided instead of sourceId. " +
        "Supports text files (md, txt, json, yaml, csv, etc). Binary files are skipped.",
      inputSchema: z.object({
        sourceId: z.string().optional().describe("Existing source identifier."),
        sourceName: z
          .string()
          .optional()
          .describe("New source name if sourceId is omitted."),
        folderPath: z
          .string()
          .min(1)
          .describe("Absolute path to a local folder to ingest."),
      }),
    },
    async ({
      sourceId,
      sourceName,
      folderPath,
    }: {
      sourceId?: string;
      sourceName?: string;
      folderPath: string;
    }): Promise<CallToolResult> => {
      let resolvedSourceId = sourceId;
      if (!resolvedSourceId) {
        if (!sourceName) {
          throw new Error("sourceName is required when sourceId is omitted");
        }
        resolvedSourceId = (await ragService.createSource(sourceName)).sourceId;
      }

      // Walk the folder and collect text files
      const files = await collectLocalFiles(folderPath);

      if (files.length === 0) {
        return toToolResult({
          sourceId: resolvedSourceId,
          message: "No readable files found in the specified folder.",
          filesFound: 0,
        });
      }

      // Upload in batches of 50
      let totalStored = 0;
      for (let i = 0; i < files.length; i += 50) {
        const batch = files.slice(i, i + 50);
        const result = await ragService.uploadFiles(resolvedSourceId, batch);
        totalStored += result.filesStored;
      }

      const sync = await ragService.syncSource(resolvedSourceId);

      return toToolResult({
        sourceId: resolvedSourceId,
        filesFound: files.length,
        filesStored: totalStored,
        ...sync,
      });
    },
  );

  return server;
}

async function collectLocalFiles(
  rootDir: string,
): Promise<Array<{ name: string; content: string; encoding: "utf8" }>> {
  const results: Array<{ name: string; content: string; encoding: "utf8" }> =
    [];

  async function walk(dir: string): Promise<void> {
    const entries = await readdir(dir, { withFileTypes: true }).catch(() => []);
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (
          !entry.name.startsWith(".") &&
          entry.name !== "node_modules" &&
          entry.name !== "__pycache__"
        ) {
          await walk(fullPath);
        }
        continue;
      }
      if (!entry.isFile() || entry.name.startsWith(".")) continue;

      const info = await stat(fullPath);
      if (info.size > 10 * 1024 * 1024) continue; // skip >10MB

      try {
        const content = await readFile(fullPath, "utf8");
        // Skip binary-looking files (>5% control chars in first 512 bytes)
        const sample = content.slice(0, 512);
        const controlChars = [...sample].filter(
          (c) => {
            const code = c.charCodeAt(0);
            return code < 32 && code !== 9 && code !== 10 && code !== 13;
          },
        ).length;
        if (sample.length > 0 && controlChars / sample.length > 0.05) continue;

        results.push({
          name: relative(rootDir, fullPath),
          content,
          encoding: "utf8",
        });
      } catch {
        // skip unreadable files
      }
    }
  }

  await walk(rootDir);
  return results;
}
