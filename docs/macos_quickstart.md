# macOS ワンクリック起動ガイド

## 前提

- Node.js 24+ がインストール済み
- Flutter SDK がインストール済み

## サーバー起動

```bash
cd /Users/nishio/ragmcp
npm install      # 初回のみ
npm run dev
```

起動後 `http://127.0.0.1:3001` で待ち受ける。確認:

```bash
curl http://127.0.0.1:3001/health
```

## Flutter アプリ起動

別ターミナルで:

```bash
cd /Users/nishio/ragmcp/flutter_app
flutter pub get   # 初回のみ
flutter run -d macos
```

## 使い方

1. アプリ下部の **Sources** タブを開く
2. **+** でソースを作成
3. **Upload** でファイルまたはフォルダを選択
4. アップロード後 **Sync** でインデックス構築
5. **Search** または **Ask** で検索・質問

## MCP クライアント（Claude Desktop / Cursor）で使う

stdio モードで起動する場合:

```bash
# ビルド済みバイナリ
./build/sea/ragmcp-server-darwin-arm64 --stdio

# または dist から直接
node dist/server.js --stdio
```

設定方法は `claude_desktop_setup.md` を参照。

## よくあるエラー

### Flutter で "Operation not permitted"

macOS サンドボックスのネットワーク権限が不足。`macos/Runner/DebugProfile.entitlements` に以下を追加:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### サーバーが起動しない（ポート使用中）

```bash
lsof -ti:3001 | xargs kill
npm run dev
```

### SQLite の ExperimentalWarning

`node:sqlite` は Node.js 24 の実験的機能。動作に問題はない。警告を消すには:

```bash
NODE_NO_WARNINGS=1 npm run dev
```
