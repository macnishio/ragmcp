# RAG MCP APIリファレンス

## 概要

RAG MCP (Retrieval-Augmented Generation Model Context Protocol) は、ローカルドキュメント検索とAI応答を提供するMCPサーバーです。

## ベースURL

```
http://127.0.0.1:3001
```

## 認証

現在のバージョンでは認証は不要です。

## APIエンドポイント

### ヘルスチェック

#### GET /health

サーバーの状態を確認します。

**レスポンス**:
```json
{
  "status": "ok",
  "data": {
    "application": "ragmcp",
    "version": "0.3.1",
    "uptime": 3600
  }
}
```

### RAGソース管理

#### GET /rag/sources

すべてのRAGソースを取得します。

**レスポンス**:
```json
{
  "data": [
    {
      "sourceId": "src_123",
      "name": "ドキュメント",
      "status": "ready",
      "sourceType": "local",
      "documentCount": 10,
      "chunkCount": 156,
      "createdAt": "2026-03-08T10:00:00Z",
      "updatedAt": "2026-03-08T10:00:00Z",
      "lastSyncedAt": "2026-03-08T09:30:00Z"
    }
  ]
}
```

#### POST /rag/sources

新しいRAGソースを作成します。

**リクエストボディ**:
```json
{
  "name": "ソース名"
}
```

**レスポンス**:
```json
{
  "data": {
    "sourceId": "src_456",
    "name": "ソース名",
    "status": "initializing",
    "sourceType": "local",
    "documentCount": 0,
    "chunkCount": 0,
    "createdAt": "2026-03-08T10:00:00Z",
    "updatedAt": "2026-03-08T10:00:00Z"
  }
}
```

#### DELETE /rag/sources/{sourceId}

指定されたRAGソースを削除します。

**パスパラメータ**:
- `sourceId`: 削除するソースのID

#### PATCH /rag/sources/{sourceId}

RAGソースの名前を変更します。

**パスパラメータ**:
- `sourceId`: 更新するソースのID

**リクエストボディ**:
```json
{
  "name": "新しいソース名"
}
```

### ファイル管理

#### POST /rag/sources/{sourceId}/files

指定されたソースにファイルをアップロードします。

**パスパラメータ**:
- `sourceId`: ファイルをアップロードするソースのID

**リクエストボディ**:
```json
{
  "files": [
    {
      "name": "document.txt",
      "content": "ZmlsZSBjb250ZW50",
      "encoding": "base64"
    }
  ]
}
```

#### POST /rag/sources/{sourceId}/sync

指定されたソースを同期します。

**パスパラメータ**:
- `sourceId`: 同期するソースのID

**レスポンス**:
```json
{
  "data": {
    "syncedDocuments": 5,
    "totalChunks": 123,
    "processingTime": 2.5
  }
}
```

### 検索

#### POST /rag/sources/{sourceId}/search

指定されたソース内で検索します。

**パスパラメータ**:
- `sourceId`: 検索するソースのID

**リクエストボディ**:
```json
{
  "query": "検索クエリ",
  "limit": 8
}
```

**レスポンス**:
```json
{
  "data": {
    "results": [
      {
        "chunkId": "chunk_123",
        "content": "関連するコンテンツ...",
        "score": 0.95,
        "metadata": {
          "source": "document.txt",
          "page": 1
        }
      }
    ]
  }
}
```

### 質問応答

#### POST /rag/sources/{sourceId}/answer

指定されたソースに対して質問します。

**パスパラメータ**:
- `sourceId`: 質問するソースのID

**リクエストボディ**:
```json
{
  "question": "質問内容",
  "limit": 5
}
```

**レスポンス**:
```json
{
  "data": {
    "question": "質問内容",
    "answer": "回答内容...",
    "citations": [
      {
        "chunkId": "chunk_123",
        "relPath": "document.txt",
        "heading": "関連セクション"
      }
    ]
  }
}
```

### スケジュール管理

#### GET /rag/schedules

すべての同期スケジュールを取得します。

**レスポンス**:
```json
{
  "data": [
    {
      "sourceId": "src_123",
      "frequency": "daily",
      "timezone": "Asia/Tokyo",
      "enabled": true,
      "nextRun": "2026-03-09T09:00:00Z"
    }
  ]
}
```

#### GET /rag/sources/{sourceId}/schedule

指定されたソースのスケジュールを取得します。

#### PUT /rag/sources/{sourceId}/schedule

指定されたソースのスケジュールを設定します。

**リクエストボディ**:
```json
{
  "frequency": "daily",
  "timezone": "Asia/Tokyo",
  "enabled": true
}
```

#### DELETE /rag/sources/{sourceId}/schedule

指定されたソースのスケジュールを削除します。

### ドキュメント管理

#### GET /rag/sources/{sourceId}/documents/{documentId}

指定されたドキュメントの詳細を取得します。

**パスパラメータ**:
- `sourceId`: ドキュメントが属するソースのID
- `documentId`: 取得するドキュメントのID

## エラーレスポンス

すべてのエラーは以下の形式で返されます：

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーの詳細説明",
    "details": {}
  }
}
```

### 一般的なエラーコード

- `400 Bad Request`: リクエストパラメータが無効
- `404 Not Found`: リソースが見つからない
- `500 Internal Server Error`: サーバー内部エラー

## 使用例

### Flutterアプリからの使用

```dart
final service = RagSourceService(baseUrl: 'http://127.0.0.1:3001');

// ソース一覧を取得
final sources = await service.fetchSources();

// 新しいソースを作成
final newSource = await service.createSource('マイドキュメント');

// ファイルをアップロード
final files = [File('document.txt')];
await service.uploadFiles(newSource.sourceId, files);

// 検索を実行
final results = await service.searchSource(newSource.sourceId, '検索語');

// 質問をする
final answer = await service.answerSource(newSource.sourceId, '質問内容');
```

### curlでの使用

```bash
# ヘルスチェック
curl http://127.0.0.1:3001/health

# ソース作成
curl -X POST http://127.0.0.1:3001/rag/sources \
  -H "Content-Type: application/json" \
  -d '{"name": "テストソース"}'

# ファイルアップロード
curl -X POST http://127.0.0.1:3001/rag/sources/src_123/files \
  -H "Content-Type: application/json" \
  -d '{"files":[{"name":"test.txt","content":"SGVsbG8gV29ybGQ=","encoding":"base64"}]}'
```

## 制限事項

- ファイルサイズ: 最大50MB
- 同時接続: 最大10接続
- 検索クエリ: 最大1000文字
- 質問: 最大500文字

## バージョン履歴

- v0.3.1: スケジュール管理機能追加
- v0.3.0: Flutterアプリ統合
- v0.2.1: 検索機能改善
- v0.2.0: 基本API実装
