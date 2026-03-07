# 新しい MCP ツールの追加手順

## 概要

ragmcp に新しいツールを追加するには、3つのファイルを編集する。

| ファイル | 役割 |
|----------|------|
| `src/services/rag/service.ts` | ビジネスロジック（DB操作） |
| `src/mcp/create-server.ts` | MCP ツール定義（stdio 経由で使用） |
| `src/routes/rag.ts` | HTTP API エンドポイント（Flutter アプリから使用） |

## 手順（例: ドキュメント削除ツールの追加）

### Step 1: ビジネスロジックを追加 — `service.ts`

`RagService` クラスにメソッドを追加する。

```typescript
// src/services/rag/service.ts

deleteDocument(sourceId: string, documentId: string): boolean {
  this.requireSource(sourceId);

  const doc = this.db
    .prepare("SELECT id FROM documents WHERE source_id = ? AND id = ?")
    .get(sourceId, documentId);

  if (!doc) return false;

  // CASCADE で chunks と chunks_fts も削除される
  this.db.prepare("DELETE FROM documents WHERE id = ?").run(documentId);
  this.touchSource(sourceId, "ready", null);
  return true;
}
```

**ポイント:**
- `this.requireSource(sourceId)` で存在チェック（無ければ例外）
- `this.db` は `DatabaseSync`（同期API）
- `this.touchSource()` で source の `updated_at` を更新

### Step 2: MCP ツールを登録 — `create-server.ts`

`server.registerTool()` で MCP クライアント（Claude Desktop 等）から呼べるようにする。

```typescript
// src/mcp/create-server.ts

server.registerTool(
  "delete_document",                    // ツール名
  {
    title: "Delete Document",           // 表示名
    description: "Delete a document from a local RAG source.",
    inputSchema: z.object({             // Zod でバリデーション
      sourceId: z.string().min(1),
      documentId: z.string().min(1),
    }),
  },
  async ({
    sourceId,
    documentId,
  }: {
    sourceId: string;
    documentId: string;
  }): Promise<CallToolResult> => {
    const deleted = ragService.deleteDocument(sourceId, documentId);
    return toToolResult({ deleted });
  },
);
```

**ポイント:**
- `inputSchema` は `z.object({...})` で定義（Zod）
- 戻り値は `toToolResult(payload)` でラップ（JSON text + structuredContent）
- ツール名はスネークケース（`delete_document`）

### Step 3: HTTP エンドポイントを追加 — `rag.ts`

Flutter アプリや curl から呼べるようにする。

```typescript
// src/routes/rag.ts

router.delete("/sources/:sourceId/documents/:documentId", (req, res) => {
  try {
    const deleted = ragService.deleteDocument(
      req.params.sourceId,
      req.params.documentId,
    );
    if (!deleted) {
      res.status(404).json({ success: false, error: "document not found" });
      return;
    }
    res.json({ success: true, data: { deleted: true } });
  } catch (error) {
    sendError(res, error);
  }
});
```

**ポイント:**
- レスポンスは `{ success: boolean, data?: T, error?: string }` 形式
- エラーは `sendError(res, error)` で統一処理
- source が見つからなければ自動的に 404 が返る（`requireSource` の例外）

### Step 4: ビルド & テスト

```bash
# 型チェック
npm run type-check

# 開発サーバーで確認
npm run dev
curl -X DELETE http://127.0.0.1:3001/rag/sources/<sourceId>/documents/<documentId>

# MCP stdio で確認
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | node dist/server.js --stdio

# SEA バイナリ再ビルド（配布する場合）
npm run sea:build
```

---

## 既存ツール一覧

| MCP ツール名 | HTTP エンドポイント | service.ts メソッド |
|-------------|---------------------|---------------------|
| `health_check` | `GET /health` | `getHealth()` |
| `list_sources` | `GET /rag/sources` | `listSources()` |
| `create_source` | `POST /rag/sources` | `createSource(name)` |
| `upload_text_document` | `POST /rag/sources/:id/files` | `uploadFiles(id, files)` + `syncSource(id)` |
| `search_source` | `POST /rag/sources/:id/search` | `searchSource(id, query, limit)` |
| `answer_source` | `POST /rag/sources/:id/answer` | `answerSource(id, question, limit)` |
| — | `POST /rag/sources/:id/sync` | `syncSource(id)` |
| — | `GET /rag/sources/:id/documents/:docId` | `getDocument(id, docId)` |

---

## DB スキーマ参照

```sql
sources   (id, name, status, source_type, created_at, updated_at, last_synced_at)
documents (id, source_id, rel_path, plain_text, content_hash, byte_size, created_at, updated_at)
chunks    (id, source_id, document_id, chunk_index, rel_path, heading, content, content_hash, created_at)
chunks_fts (chunk_id, source_id, document_id, rel_path, heading, content)  -- FTS5
```

---

## Flutter 側の対応（任意）

HTTP エンドポイントを追加した場合、Flutter アプリからも使いたければ:

1. `flutter_app/lib/services/rag_source_service.dart` にメソッド追加
2. `flutter_app/lib/screens/` の該当画面にUI追加

```dart
// rag_source_service.dart
Future<bool> deleteDocument(String sourceId, String documentId) async {
  final res = await http.delete(
    Uri.parse('$baseUrl/rag/sources/$sourceId/documents/$documentId'),
  );
  return res.statusCode == 200;
}
```
