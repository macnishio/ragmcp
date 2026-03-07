import { randomUUID, createHash } from "node:crypto";
import { mkdir, readdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";

import type { DatabaseSync } from "node:sqlite";

import type { AppPaths } from "../../system/app-paths.js";
import { ensureAppPaths } from "../../system/app-paths.js";
import type {
  AnswerResponse,
  RagHealth,
  RagSource,
  SearchResult,
  UploadedFilePayload,
} from "../../types/rag.js";
import { buildChunks } from "./chunking.js";
import { RagDatabase } from "./database.js";
import { extractTextFromBuffer } from "./parsing.js";

interface SourceRow {
  id: string;
  name: string;
  status: RagSource["status"];
  source_type: RagSource["sourceType"];
  created_at: string;
  updated_at: string;
  last_synced_at: string | null;
  document_count: number;
  chunk_count: number;
}

interface DocumentRow {
  id: string;
  source_id: string;
  rel_path: string;
  plain_text: string;
  content_hash: string;
  byte_size: number;
  created_at: string;
  updated_at: string;
}

export class RagService {
  readonly paths: AppPaths;
  readonly databasePath: string;

  private readonly db: DatabaseSync;

  constructor(paths: AppPaths = ensureAppPaths()) {
    this.paths = paths;
    this.databasePath = paths.databasePath;
    this.db = new RagDatabase(paths).database;
  }

  getHealth(): RagHealth {
    const sourceCount = this.scalar("SELECT COUNT(*) AS count FROM sources");
    const documentCount = this.scalar("SELECT COUNT(*) AS count FROM documents");
    const chunkCount = this.scalar("SELECT COUNT(*) AS count FROM chunks");

    return {
      appDataDir: this.paths.rootDir,
      databasePath: this.paths.databasePath,
      sourceCount,
      documentCount,
      chunkCount,
    };
  }

  listSources(): RagSource[] {
    const rows = this.db
      .prepare(`
        SELECT
          s.id,
          s.name,
          s.status,
          s.source_type,
          s.created_at,
          s.updated_at,
          s.last_synced_at,
          COALESCE((SELECT COUNT(*) FROM documents d WHERE d.source_id = s.id), 0) AS document_count,
          COALESCE((SELECT COUNT(*) FROM chunks c WHERE c.source_id = s.id), 0) AS chunk_count
        FROM sources s
        ORDER BY s.updated_at DESC
      `)
      .all() as unknown as SourceRow[];

    return rows.map((row) => this.mapSource(row));
  }

  getSource(sourceId: string): RagSource | null {
    const row = this.db
      .prepare(`
        SELECT
          s.id,
          s.name,
          s.status,
          s.source_type,
          s.created_at,
          s.updated_at,
          s.last_synced_at,
          COALESCE((SELECT COUNT(*) FROM documents d WHERE d.source_id = s.id), 0) AS document_count,
          COALESCE((SELECT COUNT(*) FROM chunks c WHERE c.source_id = s.id), 0) AS chunk_count
        FROM sources s
        WHERE s.id = ?
        LIMIT 1
      `)
      .get(sourceId) as SourceRow | undefined;

    return row ? this.mapSource(row) : null;
  }

  async createSource(name: string): Promise<RagSource> {
    const sourceId = `src_${randomUUID()}`;
    const now = new Date().toISOString();

    this.db
      .prepare(`
        INSERT INTO sources (id, name, status, source_type, created_at, updated_at, last_synced_at)
        VALUES (?, ?, 'empty', 'uploaded_documents', ?, ?, NULL)
      `)
      .run(sourceId, name.trim(), now, now);

    await mkdir(join(this.paths.filesDir, sourceId), { recursive: true });
    return this.requireSource(sourceId);
  }

  async deleteSource(sourceId: string): Promise<void> {
    this.requireSource(sourceId);

    this.db.exec("BEGIN");
    try {
      this.db.prepare("DELETE FROM chunks_fts WHERE source_id = ?").run(sourceId);
      this.db.prepare("DELETE FROM chunks WHERE source_id = ?").run(sourceId);
      this.db.prepare("DELETE FROM documents WHERE source_id = ?").run(sourceId);
      this.db.prepare("DELETE FROM sources WHERE id = ?").run(sourceId);
      this.db.exec("COMMIT");
    } catch (error) {
      this.db.exec("ROLLBACK");
      throw error;
    }

    const filesDir = join(this.paths.filesDir, sourceId);
    await rm(filesDir, { recursive: true, force: true });
  }

  renameSource(sourceId: string, newName: string): RagSource {
    this.requireSource(sourceId);
    const trimmed = newName.trim();
    if (!trimmed) {
      throw new Error("name must not be empty");
    }

    this.db
      .prepare("UPDATE sources SET name = ?, updated_at = ? WHERE id = ?")
      .run(trimmed, new Date().toISOString(), sourceId);

    return this.requireSource(sourceId);
  }

  async uploadFiles(sourceId: string, files: UploadedFilePayload[]): Promise<{
    filesStored: number;
  }> {
    this.requireSource(sourceId);

    const targetRoot = join(this.paths.filesDir, sourceId);
    await mkdir(targetRoot, { recursive: true });

    let filesStored = 0;
    for (const file of files) {
      const relPath = sanitizeRelativePath(file.name);
      if (!relPath) {
        continue;
      }

      const destination = join(targetRoot, relPath);
      await mkdir(dirname(destination), { recursive: true });
      const content =
        file.encoding === "utf8"
          ? Buffer.from(file.content, "utf8")
          : Buffer.from(file.content, "base64");
      await writeFile(destination, content);
      filesStored += 1;
    }

    this.touchSource(sourceId, "pending", null);
    return { filesStored };
  }

  async syncSource(sourceId: string): Promise<{
    documentCount: number;
    chunkCount: number;
    skippedFiles: string[];
  }> {
    this.requireSource(sourceId);
    const root = join(this.paths.filesDir, sourceId);
    const discovered = await walkFiles(root);
    const skippedFiles: string[] = [];
    const now = new Date().toISOString();
    const documents: DocumentRow[] = [];
    const chunksToInsert: Array<{
      id: string;
      source_id: string;
      document_id: string;
      chunk_index: number;
      rel_path: string;
      heading: string | null;
      content: string;
      content_hash: string;
      created_at: string;
    }> = [];

    for (const filePath of discovered) {
      const relPath = relative(root, filePath);
      const raw = await readFile(filePath);
      const plainText = extractTextFromBuffer(relPath, raw);
      if (!plainText) {
        skippedFiles.push(relPath);
        continue;
      }

      const documentId = `doc_${randomUUID()}`;
      const contentHash = createHash("sha256")
        .update(relPath)
        .update("\n")
        .update(plainText)
        .digest("hex");

      documents.push({
        id: documentId,
        source_id: sourceId,
        rel_path: relPath,
        plain_text: plainText,
        content_hash: contentHash,
        byte_size: raw.byteLength,
        created_at: now,
        updated_at: now,
      });

      const chunks = buildChunks({
        sourceId,
        documentId,
        relPath,
        plainText,
      });

      for (const chunk of chunks) {
        chunksToInsert.push({
          id: chunk.chunkId,
          source_id: sourceId,
          document_id: documentId,
          chunk_index: chunk.chunkIndex,
          rel_path: relPath,
          heading: chunk.heading,
          content: chunk.content,
          content_hash: chunk.contentHash,
          created_at: now,
        });
      }
    }

    this.db.exec("BEGIN");
    try {
      this.db.prepare("DELETE FROM chunks_fts WHERE source_id = ?").run(sourceId);
      this.db.prepare("DELETE FROM chunks WHERE source_id = ?").run(sourceId);
      this.db.prepare("DELETE FROM documents WHERE source_id = ?").run(sourceId);

      const insertDocument = this.db.prepare(`
        INSERT INTO documents (
          id, source_id, rel_path, plain_text, content_hash, byte_size, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const insertChunk = this.db.prepare(`
        INSERT INTO chunks (
          id, source_id, document_id, chunk_index, rel_path, heading, content, content_hash, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const insertChunkFts = this.db.prepare(`
        INSERT INTO chunks_fts (
          chunk_id, source_id, document_id, rel_path, heading, content
        ) VALUES (?, ?, ?, ?, ?, ?)
      `);

      for (const document of documents) {
        insertDocument.run(
          document.id,
          document.source_id,
          document.rel_path,
          document.plain_text,
          document.content_hash,
          document.byte_size,
          document.created_at,
          document.updated_at,
        );
      }

      for (const chunk of chunksToInsert) {
        insertChunk.run(
          chunk.id,
          chunk.source_id,
          chunk.document_id,
          chunk.chunk_index,
          chunk.rel_path,
          chunk.heading,
          chunk.content,
          chunk.content_hash,
          chunk.created_at,
        );
        insertChunkFts.run(
          chunk.id,
          chunk.source_id,
          chunk.document_id,
          chunk.rel_path,
          chunk.heading,
          chunk.content,
        );
      }

      this.db
        .prepare(`
          UPDATE sources
          SET status = ?, updated_at = ?, last_synced_at = ?
          WHERE id = ?
        `)
        .run(documents.length > 0 ? "ready" : "empty", now, now, sourceId);
      this.db.exec("COMMIT");
    } catch (error) {
      this.db.exec("ROLLBACK");
      this.touchSource(sourceId, "error", null);
      throw error;
    }

    return {
      documentCount: documents.length,
      chunkCount: chunksToInsert.length,
      skippedFiles,
    };
  }

  searchSource(sourceId: string, query: string, limit = 8): {
    sourceId: string;
    query: string;
    total: number;
    results: SearchResult[];
  } {
    this.requireSource(sourceId);
    const effectiveLimit = Math.max(1, Math.min(limit, 25));
    const ftsQuery = toFtsQuery(query);
    let rows: Array<{
      chunk_id: string;
      document_id: string;
      rel_path: string;
      heading: string | null;
      content: string;
      rank: number;
    }> = [];

    if (ftsQuery) {
      try {
        rows = this.db
          .prepare(`
            SELECT
              chunk_id,
              document_id,
              rel_path,
              heading,
              content,
              bm25(chunks_fts, 8.0, 5.0, 1.0) AS rank
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
              AND source_id = ?
            ORDER BY rank ASC
            LIMIT ?
          `)
          .all(ftsQuery, sourceId, effectiveLimit) as typeof rows;
      } catch {
        rows = [];
      }
    }

    if (rows.length === 0) {
      rows = this.db
        .prepare(`
          SELECT
            c.id AS chunk_id,
            c.document_id,
            c.rel_path,
            c.heading,
            c.content,
            1.0 AS rank
          FROM chunks c
          WHERE c.source_id = ?
            AND lower(c.content) LIKE '%' || lower(?) || '%'
          ORDER BY c.rel_path ASC, c.chunk_index ASC
          LIMIT ?
        `)
        .all(sourceId, query.trim(), effectiveLimit) as typeof rows;
    }

    const results = rows.map((row) => {
      const score = Math.max(0, Math.round(100 - row.rank * 10));
      return {
        chunkId: row.chunk_id,
        documentId: row.document_id,
        relPath: row.rel_path,
        heading: row.heading,
        content: row.content,
        excerpt: buildExcerpt(row.content, query),
        score,
        citation: {
          relPath: row.rel_path,
          heading: row.heading,
        },
      } satisfies SearchResult;
    });

    return {
      sourceId,
      query,
      total: results.length,
      results,
    };
  }

  answerSource(sourceId: string, question: string, limit = 5): AnswerResponse {
    const search = this.searchSource(sourceId, question, limit);
    if (search.results.length === 0) {
      return {
        question,
        answer: "No matching indexed passages were found in the local store.",
        citations: [],
      };
    }

    const topResults = search.results.slice(0, Math.min(3, search.results.length));
    const answerLines = topResults.map((result, index) => {
      const heading = result.heading ? ` (${result.heading})` : "";
      return `${index + 1}. ${result.excerpt} [${result.relPath}${heading}]`;
    });

    return {
      question,
      answer: [
        "Local answer draft based on indexed passages:",
        ...answerLines,
      ].join("\n"),
      citations: topResults.map((result) => ({
        chunkId: result.chunkId,
        relPath: result.relPath,
        heading: result.heading,
      })),
    };
  }

  getDocument(sourceId: string, documentId: string): {
    documentId: string;
    relPath: string;
    content: string;
  } | null {
    this.requireSource(sourceId);

    const row = this.db
      .prepare(`
        SELECT id, rel_path, plain_text
        FROM documents
        WHERE source_id = ? AND id = ?
        LIMIT 1
      `)
      .get(sourceId, documentId) as { id: string; rel_path: string; plain_text: string } | undefined;

    if (!row) {
      return null;
    }

    return {
      documentId: row.id,
      relPath: row.rel_path,
      content: row.plain_text,
    };
  }

  private mapSource(row: SourceRow): RagSource {
    return {
      sourceId: row.id,
      name: row.name,
      status: row.status,
      sourceType: row.source_type,
      documentCount: Number(row.document_count ?? 0),
      chunkCount: Number(row.chunk_count ?? 0),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      lastSyncedAt: row.last_synced_at,
    };
  }

  private requireSource(sourceId: string): RagSource {
    const source = this.getSource(sourceId);
    if (!source) {
      throw new Error(`Unknown source: ${sourceId}`);
    }
    return source;
  }

  private touchSource(
    sourceId: string,
    status: RagSource["status"],
    lastSyncedAt: string | null,
  ): void {
    this.db
      .prepare(`
        UPDATE sources
        SET status = ?, updated_at = ?, last_synced_at = ?
        WHERE id = ?
      `)
      .run(status, new Date().toISOString(), lastSyncedAt, sourceId);
  }

  private scalar(statement: string): number {
    const row = this.db.prepare(statement).get() as { count: number } | undefined;
    return Number(row?.count ?? 0);
  }
}

function toFtsQuery(query: string): string {
  const tokens =
    query.match(/[A-Za-z0-9_.:/-]{2,}|[\p{L}\p{N}]{2,}/gu)?.map((token) => token.trim()) ?? [];
  if (tokens.length === 0) {
    return "";
  }
  return tokens.map((token) => `"${token.replaceAll('"', '""')}"`).join(" OR ");
}

function buildExcerpt(content: string, query: string): string {
  const normalizedContent = content.replace(/\s+/g, " ").trim();
  const needle = query.trim().toLowerCase();
  const lower = normalizedContent.toLowerCase();
  const index = lower.indexOf(needle);

  if (index < 0) {
    return normalizedContent.slice(0, 240);
  }

  const start = Math.max(0, index - 80);
  const end = Math.min(normalizedContent.length, index + needle.length + 140);
  const excerpt = normalizedContent.slice(start, end).trim();
  return start > 0 ? `...${excerpt}` : excerpt;
}

async function walkFiles(rootDir: string): Promise<string[]> {
  const entries = await readdir(rootDir, { withFileTypes: true }).catch(() => []);
  const files: string[] = [];

  for (const entry of entries) {
    const fullPath = join(rootDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walkFiles(fullPath)));
      continue;
    }

    if (!entry.isFile() || entry.name.startsWith(".")) {
      continue;
    }

    const info = await stat(fullPath);
    if (info.size > 10 * 1024 * 1024) {
      continue;
    }
    files.push(fullPath);
  }

  return files;
}

function sanitizeRelativePath(value: string): string {
  return value
    .replaceAll("\\", "/")
    .split("/")
    .filter((segment) => segment && segment !== "." && segment !== "..")
    .join("/");
}
