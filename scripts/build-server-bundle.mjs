import { build } from "esbuild";
import { mkdir } from "node:fs/promises";

await mkdir("build", { recursive: true });

await build({
  entryPoints: ["src/server.ts"],
  outfile: "build/ragmcp-server.mjs",
  bundle: true,
  format: "esm",
  platform: "node",
  target: "node24",
  sourcemap: false,
  minify: false,
  packages: "external",
});

console.log("Bundled server at build/ragmcp-server.mjs");
