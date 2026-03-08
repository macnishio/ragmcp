# ragmcp

完全ローカルRAG（Retrieval-Augmented Generation）システム - MCPサーバーとFlutterデスクトップアプリ

クラウドサービス不要 - すべてのデータはあなたのマシン上に保持されます。

## 🌟 特徴

- **SQLite + FTS5** フルテキスト検索（BM25ランキングとLIKEフォールバック）
- **MCP stdioトランスポート** - Claude Desktop、Cursor、その他MCPクライアントで動作
- **HTTP API** - Flutterアプリとcurl用のRESTエンドポイント
- **Flutterデスクトップアプリ** - ソース管理、ファイルアップロード、検索、Q&A UI
- **ローカルフォルダ取り込み** - フォルダを指定してすべてのテキストファイルを自動インデックス
- **Node.js SEAバイナリ** - 単一実行ファイル、ランタイム依存なし

## 📥 ダウンロード

事前ビルド済みバイナリは[リリース](https://github.com/macnishio/ragmcp/releases)ページで利用可能です。

### MCPサーバー（Node.js不要）

| OS | アーキテクチャ | ファイル |
|----|-------------|------|
| macOS | ARM64 (Apple Silicon) | `ragmcp-server-darwin-arm64` |
| Linux | x64 | `ragmcp-server-linux-x64` |
| Windows | x64 | `ragmcp-server-win32-x64.exe` |

`ragmcp-server-bundle.mjs` - `node ragmcp-server-bundle.mjs`で実行する単一JSファイル（Node.js 24+が必要）

### Flutterアプリ

| OS | ファイル | 説明 |
|----|------|------|
| macOS | `macos-release.zip` | SEAサーバー同梱Flutterアプリ |
| Linux | `linux-release.tar.gz` | SEAサーバー同梱Flutterアプリ |
| Windows | `windows-release.zip` | SEAサーバー同梱Flutterアプリ |
| Android | `app-release.apk` | ローカルSQLite、サーバー不要 |

## 🚀 クイックスタート

### 方法1: Claude Desktopで使用（推奨）

1. [リリースページ](https://github.com/macnishio/ragmcp/releases)から適切なサーバーバイナリをダウンロード
2. 実行権限を付与（macOS/Linuxの場合）
3. Claude Desktopの設定ファイルに追加：

```json
{
  "mcpServers": {
    "ragmcp": {
      "command": "/path/to/ragmcp-server-darwin-arm64",
      "args": ["--stdio"]
    }
  }
}
```

4. Claude Desktopを再起動

### 方法2: Flutterアプリで使用

1. [リリースページ](https://github.com/macnishio/ragmcp/releases)からFlutterアプリをダウンロード
2. 展開して実行
3. アプリ内でファイルをアップロードまたはフォルダを指定

### 方法3: HTTP APIで使用

```bash
# サーバー起動
./ragmcp-server-win32-x64.exe

# ヘルスチェック
curl http://127.0.0.1:3001/health

# ソース作成
curl -X POST http://127.0.0.1:3001/rag/sources \
  -H "Content-Type: application/json" \
  -d '{"name": "マイドキュメント"}'

# 検索
curl -X POST http://127.0.0.1:3001/rag/sources/src_123/search \
  -H "Content-Type: application/json" \
  -d '{"query": "検索語", "limit": 8}'
```

## 📖 詳細な使用方法

### MCPサーバー設定

#### Claude Desktop

Windowsの場合、設定ファイルは `%APPDATA%\Claude\claude_desktop_config.json` にあります：

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

#### オプション

```bash
# ヘルプ表示
./ragmcp-server-win32-x64.exe --help

# カスタムポートで起動
./ragmcp-server-win32-x64.exe --port 8080

# デバッグモード
./ragmcp-server-win32-x64.exe --debug

# カスタムデータディレクトリ
./ragmcp-server-win32-x64.exe --data-dir /path/to/data
```

### Flutterアプリの使用

#### ソース管理

1. **ソース作成**: 「新規ソース」ボタンで名前を入力
2. **ファイルアップロード**: 「ファイルを追加」でローカルファイルを選択
3. **フォルダ取り込み**: 「フォルダからインポート」でディレクトリを指定

#### 検索とQ&A

1. **検索**: 検索バーにキーワードを入力
2. **質問**: 「質問」タブで自然言語質問を入力
3. **結果**: 検索結果と回答文脈が表示されます

#### 同期スケジュール

- 自動同期を設定して定期的にドキュメントを更新
- 毎日、毎週、毎月から選択可能
- タイムゾーンを設定

### サポートされるファイル形式

#### テキストファイル
- `.txt`, `.md`, `.rst`
- `.html`, `.xml`
- `.json`, `.yaml`, `.toml`
- `.csv`, `.tsv`
- ソースコード（`.js`, `.py`, `.java`, `.cpp`など）

#### ドキュメント
- `.pdf`（テキスト抽出）
- `.docx`, `.doc`
- `.xlsx`, `.xls`
- `.pptx`, `.ppt`

#### 注意点
- Google Drive仮想ファイル（`.gsheet`, `.gdoc`など）はサポートされません
- これらのファイルは一度ダウンロードして実ファイルに変換してください

## 🔧 開発

### 環境構築

```bash
# リポジトリクローン
git clone https://github.com/macnishio/ragmcp.git
cd ragmcp

# 依存関係インストール
npm install

# 開発サーバー起動
npm run dev

# ビルド
npm run build

# テスト
npm test
```

### Flutterアプリ開発

```bash
cd flutter_app
flutter pub get
flutter run
```

## 📚 APIリファレンス

詳細なAPIドキュメントは[API_REFERENCE.md](docs/API_REFERENCE.md)を参照してください。

## 🐛 トラブルシューティング

### 一般的な問題

#### サーバーが起動しない
- ポート3001が他のプロセスで使用されていないか確認
- ファイアウォール設定を確認

#### Claude Desktopで認識されない
- 設定ファイルのパスが正しいか確認
- サーバーの実行権限を確認（macOS/Linux）

#### ファイルアップロードが失敗する
- ファイルサイズが50MBを超えていないか確認
- サポートされているファイル形式か確認

#### 検索結果が空
- インデックスが完了しているか確認
- 検索キーワードが正しいか確認

### Windows固有の問題

#### Google Driveファイルでエラー
- Google Drive仮想ファイルは直接読み込めません
- ローカルにコピーして使用してください

#### パスの問題
- 日本語を含むパスは引用符で囲んでください
- バックスラッシュはエスケープが必要な場合があります

## 🤝 貢献

1. Forkする
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. コミット (`git commit -m 'Add amazing feature'`)
4. プッシュ (`git push origin feature/amazing-feature`)
5. Pull Requestを作成

## 📄 ライセンス

このプロジェクトはMITライセンスの下でライセンスされています。

## 🔗 関連プロジェクト

- [MCPプロトコル仕様](https://modelcontextprotocol.io/)
- [Claude Desktop](https://claude.ai/download)
- [Flutter](https://flutter.dev/)

## 📞 サポート

問題が発生した場合：
1. [既存のIssue](https://github.com/macnishio/ragmcp/issues)を確認
2. 新しいIssueを作成
3. バグレポートには詳細な情報を含めてください

---

**ragmcp** - プライバシーを重視したローカルRAGソリューション

| OS | File |
|----|------|
| macOS | `macos-release.zip` |
| Linux | `linux-release.tar.gz` |
| Windows | `windows-release.zip` |
| Android | `app-release.apk` |

## Quick start (macOS)

### Option A: Download binary (recommended)

1. Download `ragmcp-server-darwin-arm64` from [Releases](https://github.com/macnishio/ragmcp/releases)
2. `chmod +x ragmcp-server-darwin-arm64`
3. `./ragmcp-server-darwin-arm64` — starts HTTP server on port 3001
4. Download `macos-release.zip`, unzip, and run the Flutter app

### Option B: Build from source

Prerequisites: Node.js 24+, Flutter SDK

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
