import { appendFile, readFile, readdir, stat } from "node:fs/promises";
import { join, relative } from "node:path";

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

import type { RagService } from "../services/rag/service.js";

// Debug logging only in development mode
const DEBUG_LOG_PATH = join(process.cwd(), "debug-8d1b2e.log");
const IS_DEVELOPMENT = process.env.NODE_ENV !== "production";

function debugLog(message: string, data: Record<string, unknown>, hypothesisId: string): void {
  if (!IS_DEVELOPMENT) return; // Skip logging in production
  
  const payload = {
    sessionId: "8d1b2e",
    location: "create-server.ts",
    message,
    data,
    timestamp: Date.now(),
    hypothesisId,
  };
  appendFile(DEBUG_LOG_PATH, JSON.stringify(payload) + "\n").catch(() => {});
  fetch("http://127.0.0.1:7306/ingest/87542dba-b64c-4039-8371-0629646a220b", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Debug-Session-Id": "8d1b2e" },
    body: JSON.stringify(payload),
  }).catch(() => {});
}

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
      const normalizedPath = normalizeFolderPath(folderPath);
      // #region agent log
      debugLog("ingest_local_folder received folderPath", { folderPath, normalizedPath, pathLength: folderPath?.length }, "H1");
      const statResult = await stat(normalizedPath).then(
        (s) => ({ ok: true, isDirectory: s.isDirectory(), size: s.size }),
        (e: unknown) => ({ ok: false, error: String((e as Error)?.message ?? e) }),
      );
      debugLog("folder stat from server process", { folderPath: normalizedPath.slice(0, 80), ...statResult }, "H5");
      // #endregion

      let resolvedSourceId = sourceId;
      if (!resolvedSourceId) {
        if (!sourceName) {
          throw new Error("sourceName is required when sourceId is omitted");
        }
        resolvedSourceId = (await ragService.createSource(sourceName)).sourceId;
      }

      // Walk the folder to collect file paths (not contents) to avoid OOM
      const filePaths = await collectLocalFilePaths(normalizedPath);

      // #region agent log
      debugLog("filePaths count and sample", { filePathsLength: filePaths.length, firstPath: filePaths[0] ?? null }, "H2");
      // #endregion

      if (filePaths.length === 0) {
        return toToolResult({
          sourceId: resolvedSourceId,
          message: "No readable files found in the specified folder.",
          filesFound: 0,
        });
      }

      // Read and upload in batches of 50 to bound memory usage
      let totalStored = 0;
      for (let i = 0; i < filePaths.length; i += 50) {
        const batchPaths = filePaths.slice(i, i + 50);
        const batch = await readFileBatch(folderPath, batchPaths);
        // #region agent log
        if (i === 0) {
          debugLog("first batch read result", {
            batchPathsCount: batchPaths.length,
            batchReadCount: batch.length,
            firstFileName: batch[0]?.name ?? null,
          }, "H3");
        }
        // #endregion
        if (batch.length > 0) {
          const result = await ragService.uploadFiles(resolvedSourceId, batch);
          totalStored += result.filesStored;
        }
      }

      const sync = await ragService.syncSource(resolvedSourceId);

      return toToolResult({
        sourceId: resolvedSourceId,
        filesFound: filePaths.length,
        filesStored: totalStored,
        ...sync,
      });
    },
  );

  server.registerTool(
    "register_sync_schedule",
    {
      title: "Register Sync Schedule",
      description: "Create or update a scheduled sync for a local RAG source.",
      inputSchema: z.object({
        sourceId: z.string().min(1).describe("Source identifier."),
        frequency: z.enum(["daily_3am", "every_6h", "every_12h", "weekly", "monthly"]).describe("Sync frequency."),
        timezone: z.string().default("Asia/Tokyo").describe("IANA timezone name."),
        enabled: z.boolean().default(true).describe("Whether the schedule is active."),
      }),
    },
    async ({
      sourceId,
      frequency,
      timezone,
      enabled,
    }: {
      sourceId: string;
      frequency: "daily_3am" | "every_6h" | "every_12h" | "weekly" | "monthly";
      timezone: string;
      enabled: boolean;
    }): Promise<CallToolResult> => {
      const schedule = ragService.upsertSchedule(sourceId, frequency, timezone, enabled);
      return toToolResult(schedule);
    },
  );

  server.registerTool(
    "list_sync_schedules",
    {
      title: "List Sync Schedules",
      description: "List all scheduled syncs for local RAG sources.",
      inputSchema: z.object({}),
    },
    async (): Promise<CallToolResult> => toToolResult({ schedules: ragService.listSchedules() }),
  );

  server.registerTool(
    "delete_sync_schedule",
    {
      title: "Delete Sync Schedule",
      description: "Delete a scheduled sync for a local RAG source.",
      inputSchema: z.object({
        sourceId: z.string().min(1).describe("Source identifier."),
      }),
    },
    async ({ sourceId }: { sourceId: string }): Promise<CallToolResult> => {
      ragService.deleteSchedule(sourceId);
      return toToolResult({ deleted: true, sourceId });
    },
  );

  return server;
}

// Phase 1: Collect file paths only (no content loaded) to avoid OOM
/**
 * Normalize a folder path for the current platform.
 * - Converts WSL-style /mnt/<drive>/... to <DRIVE>:\... on Windows
 * - Converts forward slashes to backslashes on Windows
 * - Trims surrounding quotes and whitespace
 */
function normalizeFolderPath(inputPath: string): string {
  let p = inputPath.trim().replace(/^["']|["']$/g, "");

  if (process.platform === "win32") {
    // WSL path: /mnt/c/Users/... → C:\Users\...
    const wslMatch = p.match(/^\/mnt\/([a-zA-Z])\/(.*)/);
    if (wslMatch) {
      p = `${wslMatch[1].toUpperCase()}:\\${wslMatch[2].replace(/\//g, "\\")}`;
    } else if (/^\/[a-zA-Z]\//.test(p)) {
      // MSYS/Git Bash style: /c/Users/... → C:\Users\...
      p = `${p[1].toUpperCase()}:\\${p.slice(3).replace(/\//g, "\\")}`;
    } else {
      // Just normalize slashes
      p = p.replace(/\//g, "\\");
    }
  }

  return p;
}

async function collectLocalFilePaths(rootDir: string): Promise<string[]> {
  const paths: string[] = [];

  async function walk(dir: string): Promise<void> {
    const entries = await readdir(dir, { withFileTypes: true }).catch((err) => {
      // #region agent log
      debugLog("readdir failed", { dir, error: String((err as Error)?.message ?? err) }, "H5");
      // #endregion
      return [];
    });
    // #region agent log
    if (paths.length === 0 && dir === rootDir) {
      debugLog("root readdir result", { rootDir, entriesCount: Array.isArray(entries) ? entries.length : 0 }, "H2");
    }
    // #endregion
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

      const info = await stat(fullPath).catch(() => null);
      if (!info || info.size > 50 * 1024 * 1024) continue; // skip >50MB (increased from 10MB)

      // Accept text files by extension and content check
      const ext = entry.name.toLowerCase().split('.').pop();
      const isTextFile = ext === 'txt' || ext === 'md' || ext === 'json' || ext === 'yaml' || 
                        ext === 'yml' || ext === 'csv' || ext === 'tsv' || ext === 'log' ||
                        ext === 'rst' || ext === 'html' || ext === 'xml';
      
      if (isTextFile) {
        paths.push(fullPath);
        debugLog("added text file", { fileName: entry.name, size: info?.size }, "H3");
        continue;
      }

      // For other files, check if they're actually text by reading a small sample
      try {
        const content = await readFile(fullPath, { encoding: 'utf8' });
        const sample = content.slice(0, 512);
        const controlChars = [...sample].filter((c) => {
          const code = c.charCodeAt(0);
          return code < 32 && code !== 9 && code !== 10 && code !== 13;
        }).length;
        
        if (sample.length > 0 && controlChars / sample.length <= 0.05) {
          paths.push(fullPath);
          debugLog("added file by content check", { fileName: entry.name, size: info?.size }, "H3");
        }
      } catch {
        // Skip unreadable files
        debugLog("skipped unreadable file", { fileName: entry.name }, "H3");
      }
    }
  }

  await walk(rootDir);
  debugLog("final file collection", { totalFiles: paths.length, rootDir }, "H1");
  return paths;
}

// Phase 2: Read a batch of files into memory, filter binaries
async function readFileBatch(
  rootDir: string,
  filePaths: string[],
): Promise<Array<{ name: string; content: string; encoding: "utf8" }>> {
  const results: Array<{ name: string; content: string; encoding: "utf8" }> = [];

  for (const fullPath of filePaths) {
    try {
      let content: string;
      try {
        // First try UTF-8
        content = await readFile(fullPath, "utf8");
      } catch (utf8Error) {
        // If UTF-8 fails, try other encodings
        try {
          content = await readFile(fullPath, "utf16le");
        } catch (utf16Error) {
          // Fallback to binary buffer and decode as best effort
          const buffer = await readFile(fullPath);
          content = buffer.toString("utf8", 0, Math.min(buffer.length, 1024 * 1024)); // Limit to 1MB
        }
      }

      // Skip binary-looking files (>5% control chars in first 512 bytes)
      const sample = content.slice(0, 512);
      const controlChars = [...sample].filter((c) => {
        const code = c.charCodeAt(0);
        return code < 32 && code !== 9 && code !== 10 && code !== 13;
      }).length;
      if (sample.length > 0 && controlChars / sample.length > 0.05) continue;

      // Preserve original filename including Unicode characters (e.g. Japanese)
      // Only sanitize path separators and control characters
      const originalName = relative(rootDir, fullPath).replace(/\\/g, "/");
      const safeName = originalName
        .replace(/[\x00-\x1f\x7f]/g, "") // Remove control characters only
        .replace(/\/{2,}/g, "/"); // Collapse multiple slashes

      results.push({
        name: safeName,
        content,
        encoding: "utf8",
      });
      debugLog("successfully read file", { originalName, safeName, contentLength: content.length }, "H3");
    } catch (error) {
      debugLog("failed to read file", { fullPath, error: String(error) }, "H3");
      // skip unreadable files
    }
  }

  return results;
}
