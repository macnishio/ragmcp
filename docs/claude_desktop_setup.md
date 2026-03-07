# Claude Desktop 用 MCP 設定

## 設定ファイルの場所

macOS:
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

## 設定内容

`ragmcp` を `mcpServers` の中に追加する。

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

`/path/to/ragmcp` は実際のインストールパスに置き換えてください。

既存の MCP サーバーがある場合は `mcpServers` に並列で追加する。設定例全体は `claude_desktop_config.json` を参照。

## SEA バイナリのビルド（初回のみ）

```bash
cd ragmcp
npm install
npm run build
npm run sea:build
```

ビルド後 `build/sea/ragmcp-server-darwin-arm64` が生成される。

## 反映

1. 設定ファイルを保存
2. Claude Desktop を再起動
3. チャットで「ragmcp の health_check を実行して」と指示

## 使えるツール

| ツール名 | 説明 |
|----------|------|
| `health_check` | サーバー状態確認 |
| `list_sources` | ソース一覧 |
| `create_source` | ソース作成 |
| `upload_text_document` | ドキュメント登録 + インデックス |
| `search_source` | 全文検索 |
| `answer_source` | 質問回答（引用付き） |
