# ragmcp 実装計画

作成日: 2026-03-07

## 1. 目的

`/Users/nishio/ragmcp` に、以下を満たす新規プロジェクトを作る。

- 完全ローカル動作の MCP サーバー
- 完全ローカル保存の RAG
- 既存の Node MCP テンプレートと既存 Flutter/Dart アプリに近い構成
- GitHub Public リポジトリ化
- MCP サーバーと Flutter/Dart アプリの両方でマルチプラットフォーム配布物を用意

## 2. 前提と参照元

この計画は、参照セッション ID `019cc171-c173-7b73-beac-e6fcb0fa5912` の本文を直接取得できなかったため、手元の既存コードを基準に組み立てる。

- Node 側参照:
  - `generic-mcp-template`
  - 既存 RAG 実装は `src/routes/rag_sources.mjs` と `src/services/repo_knowledge/*`
  - 現在の RAG は PostgreSQL 前提
- Flutter 側参照:
  - `mcp-voice-assistant-flutter/flutter_app`
  - 既存の分割は `lib/models`, `lib/services`, `lib/screens`, `lib/theme`, `lib/utils`, `lib/widgets`

## 3. ゴール定義

### 必須ゴール

- RAG データ保存先がローカルファイルのみ
- サーバー起動に Postgres / Redis / S3 を不要化
- Flutter アプリからローカル MCP サーバーへ接続可能
- 文書アップロード、チャンク化、検索、引用付き回答の基本導線が動く
- GitHub Public で再現可能
- GitHub Releases から各プラットフォーム向け成果物を取得可能

### 非ゴール

- 初回からクラウド同期
- マルチテナント SaaS 構成
- 外部ベクトル DB
- 初回から高度な認証基盤

## 4. 推奨アーキテクチャ

### 4.1 ルート構成

既存テンプレートと Flutter アプリの構成を崩し過ぎないため、単一リポジトリで以下を採用する。

```text
ragmcp/
├── src/                  # MCP server
├── scripts/
├── tests/
├── flutter_app/          # Flutter/Dart app
├── docs/
├── .github/workflows/
├── package.json
├── tsconfig.json
├── README.md
└── .env.example
```

### 4.2 MCP サーバー

- 言語: TypeScript
- SDK: `@modelcontextprotocol/sdk`
- トランスポート:
  - ローカル連携の基本は `stdio`
  - Flutter 連携用に `localhost` 限定の Streamable HTTP を併設
- API 層:
  - `/mcp` または `/mcp/http`
  - `/rag/sources`
  - `/rag/search`
  - `/rag/answer`
  - `/health`

### 4.3 ローカル RAG

初期リリースは「まず確実に完全ローカル」を優先し、二段階に分ける。

- v1:
  - SQLite 1ファイル保存
  - FTS5 ベース全文検索
  - チャンク、メタデータ、引用、同期状態を SQLite に保存
  - ファイル本体はアプリケーションデータ配下に保存
- v1.1:
  - ローカル埋め込みを追加
  - ベクトル列または別テーブルを同一 SQLite に保存
  - ハイブリッド検索に拡張

この順にする理由は、完全ローカル・クロスプラットフォーム・単体配布の3条件を同時に満たすには、最初からネイティブ依存の強いベクトル基盤を入れるより、まず SQLite + FTS5 で完成させる方が安全だから。

### 4.4 保存先

OS ごとのアプリデータ配下に統一する。

- macOS: `~/Library/Application Support/ragmcp/`
- Linux: `~/.local/share/ragmcp/`
- Windows: `%AppData%/ragmcp/`

保存内容:

- `rag.sqlite`
- `files/<source-id>/...`
- `cache/chunks/`
- `models/` または `embeddings/`
- `server-config.json`
- `app-config.json`

### 4.5 Flutter アプリ

既存 Flutter 構成を踏襲する。

```text
flutter_app/lib/
├── models/
├── services/
├── screens/
├── theme/
├── utils/
└── widgets/
```

最低限の画面:

- 接続設定画面
- RAG ソース一覧
- ファイル/フォルダ追加画面
- 検索画面
- 質問応答画面
- ローカルサーバー状態画面

### 4.6 サーバーとアプリの接続形態

初期設計の前提:

- サーバーは単独でも起動可能
- Flutter アプリはローカルサーバーバイナリを検出し、必要なら起動補助する
- 通信は `127.0.0.1` に限定
- 外部送信・テレメトリはデフォルト無効

## 5. 技術選定方針

### 5.1 サーバー言語とビルド

- 実装: TypeScript
- 配布: 単一バイナリ化を前提に bundle-to-CJS を採用
- 重要制約:
  - Node の Single Executable Applications は現時点で active development
  - 単一埋め込みスクリプト前提なので、実装は動的ロードを減らす
  - ESM そのままではなく、配布用は明示的に bundle する

### 5.2 ローカル DB

推奨:

- 第一候補: SQLite
- 理由:
  - 単一ファイル
  - バックアップ容易
  - 配布が簡単
  - FTS5 を使えば v1 の検索品質は十分確保しやすい

### 5.3 埋め込みモデル

段階導入にする。

- Phase A:
  - 埋め込みなし
  - FTS5 + メタデータブーストで v1 を成立させる
- Phase B:
  - ローカル埋め込みを導入
  - 候補:
    - ローカル ONNX モデル
    - Ollama 連携をオプション化
  - ただし「完全ローカル」を崩さないため、外部 API 埋め込みは採用しない

### 5.4 Flutter 配布対象

優先順位:

1. macOS
2. Windows
3. Linux
4. Android
5. iOS

補足:

- Web はローカルファイルアクセスとローカルサーバー起動制御が弱いため初期スコープから外す
- iOS はローカル常駐サーバー同梱制約が強いため、後段に回す

## 6. 実装フェーズ

## Phase 0: リポジトリ初期化

成果物:

- Public GitHub リポジトリ作成
- `ragmcp` ルート構成作成
- ライセンス、README、Issue/PR テンプレート
- GitHub Actions の土台

タスク:

- `src/`, `scripts/`, `tests/`, `flutter_app/`, `docs/` を作成
- Node と Flutter の開発コマンドを整理
- `.gitignore`, `.env.example`, `README.md` を用意

## Phase 1: ローカル MCP サーバー最小実装

成果物:

- `stdio` で起動する MCP サーバー
- `tools/list`, RAG 用基本ツール
- `localhost` HTTP ブリッジ

タスク:

- サーバーエントリ作成
- ツール登録基盤
- `health`, `sources`, `search`, `answer` の最小 API
- ロギングとエラーハンドリング整備

## Phase 2: ローカル RAG ストレージ移植

成果物:

- PostgreSQL 前提の既存 RAG を SQLite へ置換
- ローカルファイル取り込み
- チャンク化
- 検索
- 引用情報

タスク:

- 既存 `repo_knowledge` の責務を抽出
- DB 層をローカル化
- `source`, `document`, `chunk`, `sync_run` テーブル設計
- FTS5 インデックス作成
- バックグラウンド同期処理の簡素化

## Phase 3: Flutter アプリの最小導線

成果物:

- Flutter アプリ雛形
- 接続設定
- RAG ソース一覧
- ファイルアップロード
- 検索/回答画面

タスク:

- `MCPConfig`, `RagSourceService` 相当を移植
- `screens/` と `services/` を現在の分割で作成
- デスクトップ/モバイルで同じ導線にする

## Phase 4: ローカル統合

成果物:

- Flutter アプリからローカルサーバーへ接続
- 起動確認
- サーバー未起動時のガイド
- データ保存先の表示と初期化機能

タスク:

- `localhost` 接続固定化
- サーバーバイナリ検出
- 起動・停止補助
- アプリ内ステータス表示

## Phase 5: 配布パイプライン

成果物:

- サーバー配布物
- Flutter アプリ配布物
- GitHub Releases 自動生成

タスク:

- サーバー:
  - macOS / Linux / Windows の配布ジョブ
  - 単一バイナリ生成
  - 失敗時の fallback として zip 配布も残す
- Flutter:
  - macOS app
  - Windows 実行物
  - Linux 実行物
  - Android APK
  - iOS は別パイプライン

## Phase 6: 公開前ハードニング

成果物:

- インストール手順
- ローカルデータ構成の説明
- 既知制約
- サンプルデータ
- スモークテスト

タスク:

- テスト追加
- 初回セットアップの説明
- 署名/証明書が必要な配布物の手順化
- セキュリティレビュー

## 7. 推奨スケジュール

1人で進める前提の現実的な目安:

- Week 1: Phase 0-1
- Week 2: Phase 2
- Week 3: Phase 3-4
- Week 4: Phase 5-6

最初の公開ライン:

- 2026-03-07 起点で 3-4 週間
- 先に macOS 完了
- 次に Windows / Linux
- その後 Android

## 8. GitHub Public 化の進め方

- リポジトリ名案: `ragmcp`
- ライセンス案: MIT
- 初回公開ブランチ:
  - `main`
  - 開発用は `codex/...`
- 必須整備:
  - `README.md`
  - `LICENSE`
  - `CONTRIBUTING.md`
  - `.github/workflows/build.yml`
  - `.github/workflows/release.yml`
  - `.github/ISSUE_TEMPLATE/*`

Releases に載せる成果物:

- `ragmcp-server-darwin-arm64`
- `ragmcp-server-darwin-x64`
- `ragmcp-server-linux-x64`
- `ragmcp-server-windows-x64.exe`
- `ragmcp-app-macos.zip`
- `ragmcp-app-windows.zip`
- `ragmcp-app-linux.tar.gz`
- `ragmcp-app-android.apk`

## 9. テスト戦略

### サーバー

- ツール登録テスト
- RAG 取り込みテスト
- チャンク生成テスト
- FTS 検索テスト
- 引用付き回答テスト
- SQLite マイグレーションテスト

### Flutter

- モデル/サービス単体テスト
- 主要画面の widget test
- ローカルサーバー疎通の integration test

### リリース前スモークテスト

- macOS:
  - サーバーバイナリ起動
  - Flutter アプリ接続
- Windows:
  - サーバーバイナリ起動
  - ローカル DB 作成
- Linux:
  - サーバーバイナリ起動
  - 検索 API 疎通

## 10. リスクと先回り対応

### リスク 1: Node 単一バイナリ化の制約

対策:

- サーバーは配布用に CJS バンドル
- 動的 import と実行時依存探索を避ける
- 単一バイナリが難しい依存は外す
- 初回リリースは zip fallback も残す

### リスク 2: ローカル埋め込みモデルの配布サイズ

対策:

- v1 は FTS5 中心で成立させる
- 埋め込みモデルは後からダウンロード可能にする
- モデル未導入でも使える設計にする

### リスク 3: iOS の制約

対策:

- iOS は後段対応
- 先に macOS / Windows / Linux / Android を成立

### リスク 4: 既存 RAG の PostgreSQL 依存が深い

対策:

- まずスキーマと責務を切り出す
- 既存コードをそのまま持ち込まず、ローカル向けに薄く再構成する

## 11. 初期タスクリスト

着手順としては以下を推奨する。

1. `ragmcp` を Git 初期化して Public リポジトリ作成
2. Node MCP サーバーの雛形を `src/` に作る
3. SQLite スキーマとローカル保存ディレクトリを決める
4. 既存 `repo_knowledge` から必要責務だけ移植する
5. Flutter `flutter_app/` を雛形作成する
6. Flutter から `localhost` の RAG API を叩く
7. GitHub Actions でサーバー配布物を作る
8. GitHub Actions で Flutter 成果物を作る
9. README とインストール手順を書く
10. 初回 Public Release を切る

## 12. 実装時の明確な判断基準

判断をぶらさないため、以下を固定ルールにする。

- 外部 DB を入れない
- RAG データはローカルファイルだけに保存する
- サーバーはオフラインでも基本機能が使える
- Flutter アプリは既存の `models/services/screens` 分割を維持する
- 単一バイナリ配布を見据え、配布時の依存を減らす
- まず macOS で完成、その後マルチプラットフォームへ展開する

## 13. 最終的な到達像

利用者は以下の流れで使える状態を目標にする。

1. GitHub Releases から `ragmcp-server` と `ragmcp-app` を取得
2. サーバーを起動
3. Flutter アプリから `localhost` に接続
4. フォルダまたはファイルを RAG ソースとして追加
5. その場で検索または質問
6. 回答と引用をローカルだけで得る

## 14. 推奨する次アクション

次にやるべき実作業は以下。

1. `ragmcp` の初期ディレクトリと `package.json` / `flutter_app` 雛形を作る
2. SQLite ベースの RAG スキーマを先に固定する
3. MCP サーバー最小実装を作って `stdio` と `localhost` の両方で応答させる

## 15. 公式リファレンス

実装判断の根拠として、以下を基準にする。

- Node.js Single Executable Applications:
  - https://nodejs.org/api/single-executable-applications.html
- Flutter 対応プラットフォーム:
  - https://docs.flutter.dev/reference/supported-platforms
- Flutter マルチプラットフォーム統合:
  - https://docs.flutter.dev/platform-integration
- MCP TypeScript SDK サーバー実装:
  - https://ts.sdk.modelcontextprotocol.io/documents/server.html
- MCP トランスポート仕様:
  - https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
