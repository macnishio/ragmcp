# ragmcp

Fully local RAG (Retrieval-Augmented Generation) system with MCP server and Flutter desktop app.

No cloud services required — all data stays on your machine.

## Features

- **SQLite + FTS5** full-text search with BM25 ranking and LIKE fallback
- **MCP stdio transport** — works with Claude Desktop, Cursor, and other MCP clients
- **HTTP API** — REST endpoints for the Flutter app and `curl`
- **Flutter desktop app** — source management, file upload, search, and Q&A UI
- **Local folder ingestion** — point at a folder and index all text files automatically
- **Node.js SEA binary** — single executable, no runtime dependencies

## Quick start (macOS)

### Prerequisites

- Node.js 24+
- Flutter SDK (for the desktop app)

### Server

```bash
git clone https://github.com/macnishio/ragmcp.git
cd ragmcp
npm install
npm run dev
```

Server starts at `http://127.0.0.1:3001`. Verify:

```bash
curl http://127.0.0.1:3001/health
```

### Flutter app

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

### Claude Desktop (MCP)

Build the single executable and configure Claude Desktop:

```bash
npm run build
npm run sea:build
```

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ragmcp": {
      "command": "/path/to/ragmcp/build/sea/ragmcp-server-darwin-arm64",
      "args": ["--stdio"]
    }
  }
}
```

See [docs/claude_desktop_setup.md](docs/claude_desktop_setup.md) for details.

## MCP Tools

| Tool | Description |
|------|-------------|
| `health_check` | Server status |
| `list_sources` | List RAG sources |
| `create_source` | Create a new source |
| `upload_text_document` | Upload text content and index |
| `ingest_local_folder` | Read a local folder and index all files |
| `search_source` | FTS5 keyword search |
| `answer_source` | Citation-style Q&A from indexed passages |

## HTTP API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/rag/sources` | List sources |
| POST | `/rag/sources` | Create source |
| POST | `/rag/sources/:id/files` | Upload files |
| POST | `/rag/sources/:id/sync` | Re-index |
| POST | `/rag/sources/:id/search` | Search |
| POST | `/rag/sources/:id/answer` | Q&A |

## Repository layout

```text
ragmcp/
├── src/              # TypeScript server
│   ├── mcp/          # MCP tool definitions
│   ├── routes/       # HTTP API routes
│   └── services/rag/ # Core RAG logic (chunking, search, DB)
├── flutter_app/      # Flutter desktop client
├── scripts/          # SEA build scripts
├── docs/             # Setup guides and documentation
└── .github/workflows/
```

## Local data

Data is stored under the OS application-data directory:

- macOS: `~/Library/Application Support/ragmcp`
- Linux: `~/.local/share/ragmcp`
- Windows: `%AppData%/ragmcp`

Override with `RAGMCP_DATA_DIR=/custom/path`.

## Documentation

- [macOS Quick Start](docs/macos_quickstart.md)
- [Claude Desktop Setup](docs/claude_desktop_setup.md)
- [Adding MCP Tools](docs/adding_mcp_tools.md)

## License

MIT
