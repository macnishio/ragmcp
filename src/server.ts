import { pathToFileURL } from "node:url";

export { createHttpApp, main, startHttpServer, startStdioServer } from "./runtime.js";
import { main } from "./runtime.js";

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
