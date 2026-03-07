export interface RagSource {
  sourceId: string;
  name: string;
  status: "empty" | "pending" | "ready" | "error";
  sourceType: "uploaded_documents";
  documentCount: number;
  chunkCount: number;
  createdAt: string;
  updatedAt: string;
  lastSyncedAt: string | null;
}

export interface UploadedFilePayload {
  name: string;
  content: string;
  encoding?: "base64" | "utf8";
}

export interface SearchResult {
  chunkId: string;
  documentId: string;
  relPath: string;
  heading: string | null;
  content: string;
  excerpt: string;
  score: number;
  citation: {
    relPath: string;
    heading: string | null;
  };
}

export interface AnswerResponse {
  question: string;
  answer: string;
  citations: Array<{
    chunkId: string;
    relPath: string;
    heading: string | null;
  }>;
}

export interface RagHealth {
  appDataDir: string;
  databasePath: string;
  sourceCount: number;
  documentCount: number;
  chunkCount: number;
}
