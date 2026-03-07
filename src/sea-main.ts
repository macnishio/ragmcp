import { main } from "./runtime.js";

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
