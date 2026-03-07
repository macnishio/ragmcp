# ragmcp

Fully local MCP server plus Flutter client for local RAG workflows.

## Current scope

- Local-only MCP server with `stdio` and local HTTP transport
- Local-only RAG storage in SQLite
- File upload, indexing, search, and citation-style answers
- Flutter multi-platform app scaffold with matching `models/services/screens` structure

## Repository layout

```text
ragmcp/
├── src/
├── scripts/
├── tests/
├── flutter_app/
├── docs/
└── .github/workflows/
```

## Server quick start

```bash
npm install
npm run dev
```

HTTP server defaults to `http://127.0.0.1:3001`.

Useful endpoints:

- `GET /health`
- `GET /rag/sources`
- `POST /rag/sources`
- `POST /rag/sources/:sourceId/files`
- `POST /rag/sources/:sourceId/sync`
- `POST /rag/sources/:sourceId/search`
- `POST /rag/sources/:sourceId/answer`
- `POST /mcp`

## Server executable build

Local single-executable packaging for the current platform:

```bash
npm install
npm run sea:build
./build/sea/ragmcp-server-$(node -p "process.platform + '-' + process.arch")
```

On Windows, run the generated `.exe` instead.

The SEA build uses:

- an internal CJS bundle built from `src/sea-main.ts`
- `node --experimental-sea-config`
- `postject`

On macOS, the build script automatically thins a universal Node binary to the active architecture before injecting the SEA blob.

## Flutter quick start

```bash
cd flutter_app
flutter pub get
flutter run
```

The app defaults to the local server URL `http://127.0.0.1:3001`.

## Local data

By default, data is stored under the OS application-data directory:

- macOS: `~/Library/Application Support/ragmcp`
- Linux: `~/.local/share/ragmcp`
- Windows: `%AppData%/ragmcp`

Override with `RAGMCP_DATA_DIR=/custom/path`.

## Notes

- The initial scaffold indexes text-oriented files only.
- PDF and model-backed vector search are not implemented yet.
- The server currently uses `node:sqlite`, which is still marked experimental in Node.js.
- GitHub Actions now build per-platform MCP server executables with Node SEA, plus Flutter artifacts.
