import { Router } from "express";

import type { RagService } from "../services/rag/service.js";
import type { SyncFrequency, UploadedFilePayload } from "../types/rag.js";

export function createRagRouter(ragService: RagService): Router {
  const router = Router();

  router.get("/sources", (_req, res) => {
    res.json({
      success: true,
      data: ragService.listSources(),
    });
  });

  router.post("/sources", async (req, res) => {
    try {
      const name = String(req.body?.name ?? "").trim();
      if (!name) {
        res.status(400).json({
          success: false,
          error: "name is required",
        });
        return;
      }

      const source = await ragService.createSource(name);
      res.status(201).json({
        success: true,
        data: source,
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.delete("/sources/:sourceId", async (req, res) => {
    try {
      await ragService.deleteSource(req.params.sourceId);
      res.json({ success: true, data: { deleted: true } });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.patch("/sources/:sourceId", (req, res) => {
    try {
      const name = String(req.body?.name ?? "").trim();
      if (!name) {
        res.status(400).json({ success: false, error: "name is required" });
        return;
      }
      const source = ragService.renameSource(req.params.sourceId, name);
      res.json({ success: true, data: source });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/sources/:sourceId/files", async (req, res) => {
    try {
      const sourceId = req.params.sourceId;
      const files = Array.isArray(req.body?.files)
        ? (req.body.files as UploadedFilePayload[])
        : [];

      if (files.length === 0) {
        res.status(400).json({
          success: false,
          error: "files must be a non-empty array",
        });
        return;
      }

      const result = await ragService.uploadFiles(sourceId, files);
      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/sources/:sourceId/sync", async (req, res) => {
    try {
      const result = await ragService.syncSource(req.params.sourceId);
      res.json({
        success: true,
        data: result,
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/sources/:sourceId/search", (req, res) => {
    try {
      const query = String(req.body?.query ?? "").trim();
      const limit = Number(req.body?.limit ?? 8);

      if (!query) {
        res.status(400).json({
          success: false,
          error: "query is required",
        });
        return;
      }

      res.json({
        success: true,
        data: ragService.searchSource(req.params.sourceId, query, limit),
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/sources/:sourceId/answer", (req, res) => {
    try {
      const question = String(req.body?.question ?? "").trim();
      const limit = Number(req.body?.limit ?? 5);

      if (!question) {
        res.status(400).json({
          success: false,
          error: "question is required",
        });
        return;
      }

      res.json({
        success: true,
        data: ragService.answerSource(req.params.sourceId, question, limit),
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.get("/sources/:sourceId/documents/:documentId", (req, res) => {
    try {
      const document = ragService.getDocument(req.params.sourceId, req.params.documentId);
      if (!document) {
        res.status(404).json({
          success: false,
          error: "document not found",
        });
        return;
      }

      res.json({
        success: true,
        data: document,
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  // --- Schedule endpoints ---

  router.get("/schedules", (_req, res) => {
    res.json({ success: true, data: ragService.listSchedules() });
  });

  router.get("/sources/:sourceId/schedule", (req, res) => {
    try {
      const schedule = ragService.getSchedule(req.params.sourceId);
      if (!schedule) {
        res.status(404).json({ success: false, error: "No schedule found" });
        return;
      }
      res.json({ success: true, data: schedule });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.put("/sources/:sourceId/schedule", (req, res) => {
    try {
      const frequency = String(req.body?.frequency ?? "") as SyncFrequency;
      const timezone = String(req.body?.timezone ?? "Asia/Tokyo");
      const enabled = req.body?.enabled !== false;

      const validFrequencies = ["daily_3am", "every_6h", "every_12h", "weekly", "monthly"];
      if (!validFrequencies.includes(frequency)) {
        res.status(400).json({ success: false, error: `Invalid frequency. Must be one of: ${validFrequencies.join(", ")}` });
        return;
      }

      const schedule = ragService.upsertSchedule(req.params.sourceId, frequency, timezone, enabled);
      res.json({ success: true, data: schedule });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.delete("/sources/:sourceId/schedule", (req, res) => {
    try {
      ragService.deleteSchedule(req.params.sourceId);
      res.json({ success: true, data: { deleted: true } });
    } catch (error) {
      sendError(res, error);
    }
  });

  return router;
}

function sendError(res: { status: (code: number) => { json: (payload: unknown) => void } }, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  const statusCode = message.startsWith("Unknown source:") ? 404 : 500;
  res.status(statusCode).json({
    success: false,
    error: message,
  });
}
