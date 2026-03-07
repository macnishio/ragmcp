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

  return server;
}
