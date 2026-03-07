import { createHash } from "node:crypto";

import { MAX_CHUNK_CHARS } from "./constants.js";

export interface ChunkedDocumentInput {
  sourceId: string;
  documentId: string;
  relPath: string;
  plainText: string;
}

export interface ChunkRecord {
  chunkId: string;
  sourceId: string;
  documentId: string;
  relPath: string;
  chunkIndex: number;
  heading: string | null;
  content: string;
  contentHash: string;
}

function normalizeText(text: string): string {
  return text
    .replace(/\r\n/g, "\n")
    .replace(/\t/g, "  ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function splitLongBlock(block: string, maxChars: number): string[] {
  const slices: string[] = [];
  let current = block.trim();

  while (current.length > maxChars) {
    let splitAt = current.lastIndexOf(". ", maxChars);
    if (splitAt < maxChars / 2) {
      splitAt = current.lastIndexOf("\n", maxChars);
    }
    if (splitAt < maxChars / 2) {
      splitAt = maxChars;
    }
    slices.push(current.slice(0, splitAt).trim());
    current = current.slice(splitAt).trim();
  }

  if (current) {
    slices.push(current);
  }

  return slices;
}

function detectHeading(content: string): string | null {
  const firstLine = content.split("\n")[0]?.trim() ?? "";
  if (!firstLine) {
    return null;
  }

  if (firstLine.startsWith("#")) {
    return firstLine.replace(/^#+\s*/, "").trim();
  }

  if (firstLine.length <= 80) {
    return firstLine;
  }

  return null;
}

export function buildChunks(input: ChunkedDocumentInput): ChunkRecord[] {
  const normalized = normalizeText(input.plainText);
  if (!normalized) {
    return [];
  }

  const paragraphs = normalized
    .split(/\n\s*\n/)
    .flatMap((paragraph) =>
      paragraph.length > MAX_CHUNK_CHARS
        ? splitLongBlock(paragraph, MAX_CHUNK_CHARS)
        : [paragraph.trim()],
    )
    .filter(Boolean);

  const chunks: ChunkRecord[] = [];
  let current = "";

  for (const paragraph of paragraphs) {
    const candidate = current ? `${current}\n\n${paragraph}` : paragraph;
    if (candidate.length <= MAX_CHUNK_CHARS) {
      current = candidate;
      continue;
    }

    if (current) {
      chunks.push(createChunk(input, chunks.length, current));
    }
    current = paragraph;
  }

  if (current) {
    chunks.push(createChunk(input, chunks.length, current));
  }

  return chunks;
}

function createChunk(
  input: ChunkedDocumentInput,
  chunkIndex: number,
  content: string,
): ChunkRecord {
  const contentHash = createHash("sha256")
    .update(input.relPath)
    .update("\n")
    .update(content)
    .digest("hex");

  return {
    chunkId: `${input.documentId}:chunk:${chunkIndex}`,
    sourceId: input.sourceId,
    documentId: input.documentId,
    relPath: input.relPath,
    chunkIndex,
    heading: detectHeading(content),
    content,
    contentHash,
  };
}
