import { Router } from "express";

import type { RagService } from "../services/rag/service.js";

export function createHealthRouter(ragService: RagService): Router {
  const router = Router();

  router.get("/", (_req, res) => {
    res.json({
      success: true,
      data: ragService.getHealth(),
    });
  });

  return router;
}
