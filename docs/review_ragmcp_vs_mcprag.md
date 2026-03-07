# ragmcp vs mcprag 実装レビュー

作成日: 2026-03-07

## 概要

2つの独立した実装を比較レビューする。どちらも「完全ローカルのRAGシステム + MCP stdio + Flutter UI」という同じ目標を持つ。

| 項目 | ragmcp | mcprag |
|------|--------|--------|
| 言語 | TypeScript (strict) | Plain JavaScript (ESM) |
| DB | `node:sqlite` (DatabaseSync) | `better-sqlite3` |
| ビルド | esbuild + SEA | なし（直接実行） |
| テスト | vitest + supertest | なし |
| CI/CD | GitHub Actions (ci + release) | なし |
| Flutter | 3画面 + テーマ + 設定 | 3画面のみ |

---

## ragmcp の良い点（mcprag に取り入れるべき）

### 1. FTS5 フォールバック検索（LIKE）
FTS5クエリが空結果やエラーの場合、`LIKE` ベースのフォールバック検索を実施。これにより短い単語や特殊文字でも結果が返る。

```typescript
// ragmcp: service.ts L347-364
if (rows.length === 0) {
  rows = this.db.prepare(`
    SELECT ... FROM chunks c
    WHERE c.source_id = ? AND lower(c.content) LIKE '%' || lower(?) || '%'
    ORDER BY c.rel_path ASC, c.chunk_index ASC
    LIMIT ?
  `).all(sourceId, query.trim(), effectiveLimit);
}
```

**mcpragの現状**: FTS5のみ。マッチしなければ空結果。

### 2. FTS5クエリのOR結合
ragmcpは複数トークンを `"word1" OR "word2"` で結合。mcpragはスペース区切りの暗黙AND。OR結合のほうが部分マッチに強い。

```typescript
// ragmcp: toFtsQuery()
return tokens.map(t => `"${t}"`).join(" OR ");
```

### 3. 検索結果のExcerpt生成（コンテキスト付き）
ragmcpはクエリ文字列の出現位置を中心に±80-140文字のexcerptを生成。mcpragは先頭300文字のみ。

```typescript
// ragmcp: buildExcerpt()
const index = lower.indexOf(needle);
const start = Math.max(0, index - 80);
const end = Math.min(len, index + needle.length + 140);
```

### 4. チャンキングの文境界分割（splitLongBlock）
ragmcpは長いブロックを文末（`. `）またはEOL（`\n`）で分割。mcpragは固定文字数で機械的にスライス。

```typescript
// ragmcp: splitLongBlock()
let splitAt = current.lastIndexOf(". ", maxChars);
if (splitAt < maxChars / 2) splitAt = current.lastIndexOf("\n", maxChars);
if (splitAt < maxChars / 2) splitAt = maxChars;
```

### 5. バイナリファイル検出
ragmcpは先頭512バイトの制御文字数をチェックしてバイナリファイルをスキップ。mcpragはチェックなし。

```typescript
// ragmcp: looksBinary()
const sample = text.slice(0, 512);
for (const char of sample) {
  const code = char.charCodeAt(0);
  if ((code >= 0 && code <= 8) || code === 65533) controlCount++;
}
return controlCount > 8;
```

### 6. OS標準のデータディレクトリ
ragmcpは `~/Library/Application Support/ragmcp/`（macOS）等を使用。mcpragはプロジェクト内の `data/` ディレクトリ。配布バイナリとしてはOS標準パスが適切。

### 7. パスサニタイズ
ragmcpはアップロードファイルの相対パスから `..` と `.` を除去。ディレクトリトラバーサル攻撃を防止。

```typescript
// ragmcp: sanitizeRelativePath()
return value.replaceAll("\\", "/")
  .split("/")
  .filter(s => s && s !== "." && s !== "..")
  .join("/");
```

### 8. ファイルサイズ上限（10MB）
ragmcpはsync時に10MB超のファイルをスキップ。mcpragは上限なし。

### 9. Health エンドポイントの情報量
ragmcpは sourceCount, documentCount, chunkCount, データディレクトリパスを返す。mcpragは `{ok, version}` のみ。

### 10. Flutter: 設定画面 + サーバーURL永続化
ragmcpは `SharedPreferences` でサーバーURLを保存し、設定画面で変更可能。mcpragはハードコード。

### 11. Flutter: Home画面のメトリクスダッシュボード
ragmcpはサーバーの統計情報（ソース数・ドキュメント数・チャンク数）を表示。mcpragは直接ソースリストを表示。

### 12. Flutter: 型安全なモデル分離
ragmcpは `RagSource`, `RagSearchResult`, `RagAnswer`, `RagCitation` を `models/` ディレクトリに分離。mcpragは `rag_service.dart` にモデルとサービスが混在。

### 13. CI/CD パイプライン
ragmcpはCI（typecheck + test + build + flutter analyze）とRelease（マルチプラットフォームビルド + GitHub Releases）を完備。mcpragは未設定。

### 14. SEA ビルドスクリプト
ragmcpの `build-server-sea.mjs` はmacOS universal binary対応、コード署名、マルチプラットフォームを処理する完成度の高いスクリプト。

### 15. DBインデックス
ragmcpは `idx_documents_source_id`, `idx_chunks_source_id`, `idx_chunks_document_id` を明示的に作成。mcpragはUNIQUE制約のみ。

---

## mcprag の良い点（ragmcp に取り入れるべき）

### 1. FTS5 content sync トリガー
mcpragはFTS5をcontent syncモード（`content='chunks'`）で使い、INSERT/UPDATE/DELETEトリガーで自動同期。ragmcpは手動で `chunks_fts` に INSERT する必要がある。

### 2. Markdown見出し階層パース
mcpragは `parseDocument()` でMarkdownの `#` 見出しを追跡し、`headingStack` で階層パスを構築。ragmcpは最初の行が短ければ見出しとする簡易判定。

### 3. チャンクサイズ（2000 vs 1200）
mcpragの2000文字はコードファイルの検索に適している（関数全体がチャンクに収まりやすい）。ragmcpの1200文字は検索精度重視だが、コード用途では断片化する。

### 4. MCP initialize ハンドリング
mcpragは `initialize` と `notifications/initialized` を正しく処理。ragmcpはSDK任せ（`@modelcontextprotocol/sdk`）。

### 5. ON CONFLICT UPSERT
mcpragはドキュメント挿入で `ON CONFLICT(source_id, rel_path) DO UPDATE` を使用。ragmcpはsync時に全削除→全挿入。バッチアップロードではupsertのほうが安全。

---

## ragmcp の改善が必要な点

1. **FTS5の手動管理**: content sync mode + trigger のほうが安全で保守しやすい
2. **Sync必須**: アップロード後に明示的な `sync` が必要。mcpragはアップロード時に即インデックス
3. **ファイルディスク保存**: アップロードファイルをディスクに保存してからsyncで再読み込み。二重I/Oが発生
4. **node:sqlite 依存**: Node.js 24+ でないと使えない。`better-sqlite3` のほうが互換性が広い
5. **チャンクサイズ1200文字**: コードファイルには小さすぎる場合がある

## mcprag の改善が必要な点

1. **テストなし**: ユニットテスト・統合テストが存在しない
2. **CI/CDなし**: GitHub Actions未設定
3. **SEAビルド未設定**: 配布用バイナリのビルドスクリプトがない
4. **サーバーURL設定画面なし**: ハードコード
5. **バイナリファイル検出なし**: 誤ってバイナリをインジェストする可能性
6. **Healthエンドポイント情報不足**
7. **フォールバック検索なし**: FTS5のみ
8. **パスサニタイズなし**: セキュリティリスク
9. **ファイルサイズ上限なし**
10. **DBインデックス不足**: source_id, document_id の個別インデックスがない

---

## 結論

ragmcpは**プロダクション品質のビルド・配布基盤**（TypeScript strict、CI/CD、SEAバイナリ、テスト）に優れ、mcpragは**シンプルで動作するコア機能**（FTS5 trigger sync、upsert、Markdownパース）に優れる。

mcpragに取り込むべき優先度の高い機能:
1. FTS5 フォールバック検索 (LIKE)
2. Excerpt のコンテキスト表示
3. チャンク分割の文境界対応
4. バイナリファイル検出
5. パスサニタイズ
6. ファイルサイズ上限
7. Healthエンドポイント強化
8. DBインデックス追加
9. OS標準データディレクトリ
10. Flutter: 設定画面 + サーバーURL永続化
11. CI/CD + Release workflow
12. SEAビルドスクリプト
