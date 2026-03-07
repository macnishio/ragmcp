import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface AppPaths {
  rootDir: string;
  databasePath: string;
  filesDir: string;
  cacheDir: string;
  modelsDir: string;
}

function defaultDataRoot(): string {
  if (process.env.RAGMCP_DATA_DIR) {
    return process.env.RAGMCP_DATA_DIR;
  }

  if (process.platform === "darwin") {
    return join(homedir(), "Library", "Application Support", "ragmcp");
  }

  if (process.platform === "win32") {
    return join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "ragmcp");
  }

  return join(homedir(), ".local", "share", "ragmcp");
}

export function ensureAppPaths(): AppPaths {
  const rootDir = defaultDataRoot();
  const filesDir = join(rootDir, "files");
  const cacheDir = join(rootDir, "cache");
  const modelsDir = join(rootDir, "models");
  const databasePath = join(rootDir, "rag.sqlite");

  for (const directory of [rootDir, filesDir, cacheDir, modelsDir]) {
    mkdirSync(directory, { recursive: true });
  }

  return {
    rootDir,
    databasePath,
    filesDir,
    cacheDir,
    modelsDir,
  };
}
