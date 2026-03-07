import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";

import { createHttpApp } from "../src/runtime.js";
import { ensureAppPaths } from "../src/system/app-paths.js";
import { RagService } from "../src/services/rag/service.js";

const tempDirs: string[] = [];

async function createTestApp() {
  const root = await mkdtemp(join(tmpdir(), "ragmcp-test-"));
  tempDirs.push(root);
  process.env.RAGMCP_DATA_DIR = root;
  const service = new RagService(ensureAppPaths());
  return createHttpApp(service);
}

afterEach(async () => {
  delete process.env.RAGMCP_DATA_DIR;
  await Promise.all(
    tempDirs.splice(0, tempDirs.length).map((directory) =>
      rm(directory, { recursive: true, force: true }),
    ),
  );
});

describe("HTTP app", () => {
  it("returns health", async () => {
    const app = await createTestApp();
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.sourceCount).toBe(0);
  });

  it("creates, uploads, syncs, and searches a source", async () => {
    const app = await createTestApp();

    const createResponse = await request(app)
      .post("/rag/sources")
      .send({ name: "Test Source" });

    const sourceId = createResponse.body.data.sourceId as string;

    await request(app)
      .post(`/rag/sources/${sourceId}/files`)
      .send({
        files: [
          {
            name: "notes/intro.md",
            content: Buffer.from("# Intro\n\nragmcp keeps data local.\n").toString("base64"),
            encoding: "base64",
          },
        ],
      })
      .expect(201);

    await request(app)
      .post(`/rag/sources/${sourceId}/sync`)
      .send({})
      .expect(200);

    const searchResponse = await request(app)
      .post(`/rag/sources/${sourceId}/search`)
      .send({ query: "local", limit: 5 })
      .expect(200);

    expect(searchResponse.body.success).toBe(true);
    expect(searchResponse.body.data.results.length).toBeGreaterThan(0);
    expect(searchResponse.body.data.results[0].relPath).toBe("notes/intro.md");
  });
});
