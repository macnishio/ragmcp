# Windows環境でのファイル読み込み制限

## 問題
Windows環境でGoogle Driveの仮想ファイル（.gsheet, .gdocなど）を読み込もうとすると `FileSystemException` が発生します。

## 原因
1. **Google Drive仮想ファイル**: .gsheetファイルは実際のExcelファイルではなく、Google Driveの仮想ファイル
2. **ファイルシステムの制限**: WindowsのGoogle Drive同期フォルダにはアクセス制限がある
3. **日本語パス**: Windowsの日本語パス処理でのエンコーディング問題

## 対応策
アプリケーションレベルで以下のファイルを自動的に除外します：

### 除外されるファイル拡張子
```
# Google Workspace仮想ファイル
.gsheet, .gdoc, .gslides, .gdraw, .gform, .gsite

# システムファイル
.lnk, .tmp, .temp, .cache, .log

# 実行ファイル
.exe, .dll, .sys, .bat, .cmd, .ps1, .msi

# その他のバイナリ
.deb, .rpm, .dmg, .app
```

### 除外されるパス
- Google Driveフォルダ（G:\）
- 隠しファイル（.で始まるファイル）
- ビルドフォルダ

## 推奨される対応方法

### ユーザー側
1. **ローカルコピーを作成**: Google Driveのファイルを一度ダウンロードしてローカルに保存
2. **サポートされている形式に変換**: .gsheet → .xlsx, .gdoc → .docx
3. **Google Drive以外のフォルダを使用**: ローカルのDocumentsフォルダなど

### 開発者側
1. **ファイルフィルタリング**: 実装済み
2. **エラーハンドリング**: 実装済み
3. **ユーザー通知**: 実装済み

## 技術詳細

### エラー例
```
FileSystemException: readInto failed, path = G:\マイドライブ\...\現金売上.xlsx.gsheet
(OS Error: ファンクションが間違っています。, errno = 1)
```

### 対応コード
```dart
bool _isUnsupportedFile(File file) {
  final fileName = file.path.toLowerCase();
  final unsupportedExtensions = ['.gsheet', '.gdoc', /* ... */];
  
  if (fileName.contains('google drive') || 
      fileName.startsWith('g:\\') ||
      unsupportedExtensions.any((ext) => fileName.endsWith(ext))) {
    return true;
  }
  
  return false;
}
```

## 今後の改善
- Google Drive API直接連携
- クラウドファイルの自動ダウンロード
- より詳細なエラー通知
