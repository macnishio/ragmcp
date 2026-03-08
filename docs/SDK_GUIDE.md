# RAG MCP SDK Guide

## Overview

RAG MCP provides both an HTTP API and MCP (Model Context Protocol) interface for integrating with local RAG systems.

## Installation

### Prerequisites
- Node.js 24+ (recommended)
- Flutter SDK (for mobile/desktop apps)
- SQLite 3.0+

### Quick Start

```bash
# Clone and install
git clone https://github.com/macnishio/ragmcp.git
cd ragmcp
npm install

# Build the server
npm run build

# Start the server
npm start
```

## API Reference

### HTTP API

#### Health Check
```bash
curl http://127.0.0.1:3001/health
```

#### RAG Sources Management
```bash
# List sources
curl http://127.0.0.1:3001/rag/sources

# Create source
curl -X POST http://127.0.0.1:3001/rag/sources \
  -H "Content-Type: application/json" \
  -d '{"name": "My Documents"}'

# Ingest local folder
curl -X POST http://127.0.0.1:3001/mcp/call \
  -H "Content-Type: application/json" \
  -d '{"name": "ingest_local_folder", "arguments": {"sourceName": "My Docs", "folderPath": "/path/to/docs"}}'
```

#### Search and Q&A
```bash
# Search documents
curl -X POST http://127.0.0.1:3001/rag/sources/{sourceId}/search \
  -H "Content-Type: application/json" \
  -d '{"query": "search term", "limit": 5}'

# Ask questions
curl -X POST http://127.0.0.1:3001/rag/sources/{sourceId}/answer \
  -H "Content-Type: application/json" \
  -d '{"question": "What is this about?", "limit": 3}'
```

### MCP Interface

#### Available Tools

- `create_source` - Create a new RAG source
- `delete_source` - Delete a RAG source
- `upload_files` - Upload files to a source
- `sync_source` - Process and index uploaded files
- `search_source` - Search indexed documents
- `answer_source` - Get AI-powered answers
- `ingest_local_folder` - Ingest entire local folder
- `list_sources` - List all RAG sources
- `fetch_health` - Check system health

#### Usage with Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ragmcp": {
      "command": "C:\\path\\to\\ragmcp-server-win32-x64.exe",
      "args": ["--stdio"]
    }
  }
}
```

## File Support

### Supported Formats

**Text Files** (direct processing):
- `.txt`, `.md`, `.rst`
- `.json`, `.yaml`, `.toml`, `.csv`, `.tsv`
- `.html`, `.xml`, `.log`

**Document Files** (with text extraction):
- `.pdf` - Using pdf-parse library
- `.docx`, `.doc` - Text extraction
- `.xlsx`, `.xls` - CSV data extraction

**File Size Limits**:
- Maximum 50MB per file
- Automatic binary detection and filtering

### Japanese Text Support

- **Full-text search**: Unicode61 FTS with BM25 ranking
- **CJK support**: Trigram FTS for Japanese characters
- **Encoding handling**: UTF-8, UTF-16LE, best-effort fallback
- **Character variations**: Hiragana/Katakana conversion, half/full-width support
- **Search normalization**: NFKC, punctuation handling

## Flutter Integration

### Local RAG Service

The Flutter app includes a local RAG service for offline usage:

```dart
import 'package:flutter_app/services/local_rag_service.dart';

final ragService = LocalRAGService();

// Create source
final source = await ragService.createSource('Documents');

// Upload files
await ragService.uploadFiles(source.sourceId, files);

// Search with Japanese text support
final results = await ragService.searchSource(
  source.sourceId, 
  '売上高', // Japanese search terms work
  limit: 10,
);
```

### HTTP Service

For server-connected apps:

```dart
import 'package:flutter_app/services/rag_source_service.dart';

final ragService = RagSourceService(
  baseUrl: 'http://127.0.0.1:3001',
);

// Enhanced Japanese search with multiple variations
final results = await ragService.searchSource(
  sourceId, 
  '売上高', // Automatically tries: 売上高, 売上コ, うりかたこ, etc.
  limit: 10,
);
```

## Configuration

### Environment Variables

```bash
# Server configuration
PORT=3001
NODE_ENV=production

# Database path
RAG_DATA_PATH=./data

# Logging
LOG_LEVEL=info
```

### Server Options

```bash
# Start with custom port
ragmcp-server --port 8080

# Enable debug mode
ragmcp-server --debug

# Custom data directory
ragmcp-server --data-dir /path/to/data

# Show help
ragmcp-server --help
```

## Development

### Project Structure

```
src/
├── mcp/           # MCP server interface
├── routes/         # HTTP API endpoints
├── services/rag/   # Core RAG functionality
│   ├── database.ts    # SQLite operations
│   ├── parsing.ts     # Text extraction
│   ├── chunking.ts    # Document chunking
│   ├── pdf-extraction.ts # PDF processing
│   └── search-encoding.ts # Japanese text support
└── system/         # System utilities
```

### Building

```bash
# Development build
npm run dev

# Production build
npm run build

# Create standalone executable
npm run sea:build

# Run tests
npm test

# Type checking
npm run type-check
```

### Testing

```bash
# Unit tests
npm test

# Integration tests
npm run test:integration

# Type checking
npm run type-check

# Flutter tests
cd flutter_app && flutter test
```

## Deployment

### Production Deployment

1. **Build the server**:
   ```bash
   npm run build
   npm run sea:build
   ```

2. **Configure environment**:
   ```bash
   export NODE_ENV=production
   export RAG_DATA_PATH=/opt/ragmcp/data
   ```

3. **Start the server**:
   ```bash
   ./dist/ragmcp-server-win32-x64.exe
   ```

### Docker Deployment

```dockerfile
FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY dist/ ./dist/
COPY data/ ./data/

EXPOSE 3001

CMD ["node", "./dist/sea-main.js"]
```

## Security Considerations

### Data Privacy
- All data remains local by default
- No external API calls required
- SQLite database with file-based storage

### Access Control
- No built-in authentication (add reverse proxy if needed)
- Consider API gateway for production use
- Implement rate limiting for public deployments

### File Security
- Automatic binary file detection
- File size limits (50MB default)
- Path traversal protection

## Troubleshooting

### Common Issues

**Japanese search not working**:
- Ensure proper UTF-8 encoding in source files
- Check if trigram FTS is enabled
- Try character variations (hiragana/katakana)

**PDF extraction fails**:
- Install `pdftotext` system package for better results
- Check file permissions
- Verify PDF is not password-protected

**Memory issues**:
- Reduce file size limits
- Process files in smaller batches
- Use streaming for large files

**Performance optimization**:
- Enable SQLite FTS indexing
- Regular database maintenance
- Monitor memory usage

## License

MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/macnishio/ragmcp/issues)
- **Discussions**: [GitHub Discussions](https://github.com/macnishio/ragmcp/discussions)
- **Documentation**: [Wiki](https://github.com/macnishio/ragmcp/wiki)
