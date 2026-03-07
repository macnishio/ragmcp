import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import cors from "cors";
import express, { type Request, type Response } from "express";

import { createMcpServer } from "./mcp/create-server.js";
import { createHealthRouter } from "./routes/health.js";
import { createRagRouter } from "./routes/rag.js";
import { SyncScheduler } from "./services/rag/scheduler.js";
import { RagService } from "./services/rag/service.js";

export function createHttpApp(ragService = new RagService()) {
  const app = express();

  app.disable("x-powered-by");
  app.use(cors());
  app.use(express.json({ limit: "100mb" }));

  app.get("/", (_req, res) => {
    res.json({
      success: true,
      message: "ragmcp local server is running",
      data: ragService.getHealth(),
    });
  });

  app.use("/health", createHealthRouter(ragService));
  app.use("/rag", createRagRouter(ragService));

  app.all("/mcp", async (req: Request, res: Response) => {
    const server = createMcpServer(ragService);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });

    res.on("close", () => {
      transport.close().catch(() => {});
      server.close().catch(() => {});
    });

    try {
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    } catch (error) {
      console.error("MCP error:", error);
      if (!res.headersSent) {
        res.status(500).json({
          jsonrpc: "2.0",
          error: { code: -32603, message: "Internal server error" },
          id: null,
        });
      }
    }
  });

  return app;
}

export async function startHttpServer(): Promise<void> {
  const ragService = new RagService();
  const scheduler = new SyncScheduler(ragService);
  scheduler.start();
  const app = createHttpApp(ragService);
  const host = process.env.HOST ?? "127.0.0.1";
  const port = Number.parseInt(process.env.PORT ?? "3001", 10);

  await new Promise<void>((resolve, reject) => {
    const server = app.listen(port, host, () => {
      console.log(`ragmcp HTTP server listening on http://${host}:${port}`);
      resolve();
    });

    server.on("error", reject);
  });
}

export async function startStdioServer(): Promise<void> {
  const ragService = new RagService();
  const scheduler = new SyncScheduler(ragService);
  scheduler.start();
  await createMcpServer(ragService).connect(new StdioServerTransport());
}

export async function main(argv = process.argv): Promise<void> {
  if (argv.includes("--stdio")) {
    await startStdioServer();
    return;
  }
  await startHttpServer();
}
