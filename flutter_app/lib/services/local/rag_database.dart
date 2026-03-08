import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class RagDatabase {
  final Database db;
  final String filesDir;

  RagDatabase._(this.db, this.filesDir);

  static RagDatabase open(String appDataDir) {
    final ragDir = p.join(appDataDir, 'ragmcp');
    final filesDir = p.join(ragDir, 'files');
    Directory(ragDir).createSync(recursive: true);
    Directory(filesDir).createSync(recursive: true);

    final dbPath = p.join(ragDir, 'rag.db');
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    _initialize(db);

    return RagDatabase._(db, filesDir);
  }

  static void _initialize(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'uploaded_documents',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT
      );

      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        rel_path TEXT NOT NULL,
        plain_text TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS chunks (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        rel_path TEXT NOT NULL,
        heading TEXT,
        content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE CASCADE,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_documents_source_id ON documents(source_id);
      CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON chunks(source_id);
      CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON chunks(document_id);

      CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
        chunk_id UNINDEXED,
        source_id UNINDEXED,
        document_id UNINDEXED,
        rel_path,
        heading,
        content,
        tokenize = 'unicode61'
      );

      CREATE VIRTUAL TABLE IF NOT EXISTS chunks_trigram USING fts5(
        chunk_id UNINDEXED,
        source_id UNINDEXED,
        document_id UNINDEXED,
        rel_path,
        heading,
        content,
        tokenize = 'trigram'
      );
    ''');
  }

  void dispose() {
    db.dispose();
  }
}
