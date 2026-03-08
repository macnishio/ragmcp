import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Row;
import 'package:uuid/uuid.dart';

import '../models/rag_source.dart';
import '../models/sync_schedule.dart';
import 'local/chunking.dart';
import 'local/parsing.dart';
import 'local/rag_database.dart';
import 'local/search_helpers.dart';
import 'rag_service_interface.dart';

const _uuid = Uuid();

class LocalRagService implements RagServiceInterface {
  final RagDatabase _ragDb;

  LocalRagService._(this._ragDb);

  static LocalRagService open(String appDataDir) {
    final ragDb = RagDatabase.open(appDataDir);
    return LocalRagService._(ragDb);
  }

  void dispose() {
    _ragDb.dispose();
  }

  int _scalar(String sql) {
    final result = _ragDb.db.select(sql);
    return result.isEmpty ? 0 : (result.first.values.first as int? ?? 0);
  }

  @override
  Future<Map<String, dynamic>> fetchHealth() async {
    return {
      'sourceCount': _scalar('SELECT COUNT(*) FROM sources'),
      'documentCount': _scalar('SELECT COUNT(*) FROM documents'),
      'chunkCount': _scalar('SELECT COUNT(*) FROM chunks'),
    };
  }

  @override
  Future<List<RagSource>> fetchSources() async {
    final rows = _ragDb.db.select('''
      SELECT
        s.id,
        s.name,
        s.status,
        s.source_type,
        s.created_at,
        s.updated_at,
        s.last_synced_at,
        COALESCE((SELECT COUNT(*) FROM documents d WHERE d.source_id = s.id), 0) AS document_count,
        COALESCE((SELECT COUNT(*) FROM chunks c WHERE c.source_id = s.id), 0) AS chunk_count
      FROM sources s
      ORDER BY s.updated_at DESC
    ''');

    return rows.map((row) => _mapSourceRow(row)).toList();
  }

  @override
  Future<RagSource> createSource(String name) async {
    final sourceId = 'src_${_uuid.v4()}';
    final now = DateTime.now().toUtc().toIso8601String();

    _ragDb.db.execute(
      "INSERT INTO sources (id, name, status, source_type, created_at, updated_at, last_synced_at) VALUES (?, ?, 'empty', 'uploaded_documents', ?, ?, NULL)",
      [sourceId, name.trim(), now, now],
    );

    Directory(p.join(_ragDb.filesDir, sourceId)).createSync(recursive: true);
    return _requireSource(sourceId);
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    _requireSource(sourceId);
    final db = _ragDb.db;

    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM chunks_trigram WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM chunks_fts WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM chunks WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM documents WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM sources WHERE id = ?', [sourceId]);
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    final filesDir = Directory(p.join(_ragDb.filesDir, sourceId));
    if (filesDir.existsSync()) {
      filesDir.deleteSync(recursive: true);
    }
  }

  @override
  Future<RagSource> renameSource(String sourceId, String name) async {
    _requireSource(sourceId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('name must not be empty');

    _ragDb.db.execute(
      'UPDATE sources SET name = ?, updated_at = ? WHERE id = ?',
      [trimmed, DateTime.now().toUtc().toIso8601String(), sourceId],
    );

    return _requireSource(sourceId);
  }

  @override
  Future<void> uploadFiles(String sourceId, List<File> files, {String? basePath}) async {
    _requireSource(sourceId);
    final targetRoot = p.join(_ragDb.filesDir, sourceId);
    Directory(targetRoot).createSync(recursive: true);

    for (final file in files) {
      if (_isUnsupportedFile(file)) continue;

      try {
        final bytes = await file.readAsBytes();
        var relPath = file.uri.pathSegments.last;
        if (basePath != null && file.path.startsWith(basePath)) {
          relPath = file.path.substring(basePath.length).replaceFirst(RegExp(r'^[\\/]+'), '');
        }
        relPath = _sanitizeRelativePath(relPath);
        if (relPath.isEmpty) continue;

        final destination = p.join(targetRoot, relPath);
        Directory(p.dirname(destination)).createSync(recursive: true);
        File(destination).writeAsBytesSync(bytes);
      } catch (_) {
        continue;
      }
    }

    _touchSource(sourceId, 'pending', null);
  }

  @override
  Future<Map<String, dynamic>> syncSource(String sourceId) async {
    _requireSource(sourceId);
    final root = p.join(_ragDb.filesDir, sourceId);
    final discovered = await _walkFiles(root);
    final skippedFiles = <String>[];
    final now = DateTime.now().toUtc().toIso8601String();
    final documents = <Map<String, dynamic>>[];
    final chunksToInsert = <Map<String, dynamic>>[];

    for (final filePath in discovered) {
      final relPath = p.relative(filePath, from: root);
      final raw = await File(filePath).readAsBytes();
      final plainText = extractText(relPath, raw);
      if (plainText == null) {
        skippedFiles.add(relPath);
        continue;
      }

      final documentId = 'doc_${_uuid.v4()}';
      final hashBytes = utf8.encode('$relPath\n$plainText');
      final contentHash = sha256.convert(hashBytes).toString();

      documents.add({
        'id': documentId,
        'source_id': sourceId,
        'rel_path': relPath,
        'plain_text': plainText,
        'content_hash': contentHash,
        'byte_size': raw.length,
        'created_at': now,
        'updated_at': now,
      });

      final chunks = buildChunks(
        sourceId: sourceId,
        documentId: documentId,
        relPath: relPath,
        plainText: plainText,
      );

      for (final chunk in chunks) {
        chunksToInsert.add({
          'id': chunk.chunkId,
          'source_id': sourceId,
          'document_id': documentId,
          'chunk_index': chunk.chunkIndex,
          'rel_path': relPath,
          'heading': chunk.heading,
          'content': chunk.content,
          'content_hash': chunk.contentHash,
          'created_at': now,
        });
      }
    }

    final db = _ragDb.db;
    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM chunks_trigram WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM chunks_fts WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM chunks WHERE source_id = ?', [sourceId]);
      db.execute('DELETE FROM documents WHERE source_id = ?', [sourceId]);

      final insertDoc = db.prepare(
        'INSERT INTO documents (id, source_id, rel_path, plain_text, content_hash, byte_size, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      );
      final insertChunk = db.prepare(
        'INSERT INTO chunks (id, source_id, document_id, chunk_index, rel_path, heading, content, content_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      );
      final insertFts = db.prepare(
        'INSERT INTO chunks_fts (chunk_id, source_id, document_id, rel_path, heading, content) VALUES (?, ?, ?, ?, ?, ?)',
      );
      final insertTrigram = db.prepare(
        'INSERT INTO chunks_trigram (chunk_id, source_id, document_id, rel_path, heading, content) VALUES (?, ?, ?, ?, ?, ?)',
      );

      for (final doc in documents) {
        insertDoc.execute([
          doc['id'], doc['source_id'], doc['rel_path'], doc['plain_text'],
          doc['content_hash'], doc['byte_size'], doc['created_at'], doc['updated_at'],
        ]);
      }

      for (final chunk in chunksToInsert) {
        insertChunk.execute([
          chunk['id'], chunk['source_id'], chunk['document_id'], chunk['chunk_index'],
          chunk['rel_path'], chunk['heading'], chunk['content'], chunk['content_hash'],
          chunk['created_at'],
        ]);
        insertFts.execute([
          chunk['id'], chunk['source_id'], chunk['document_id'],
          chunk['rel_path'], chunk['heading'], chunk['content'],
        ]);
        insertTrigram.execute([
          chunk['id'], chunk['source_id'], chunk['document_id'],
          chunk['rel_path'], chunk['heading'], chunk['content'],
        ]);
      }

      db.execute(
        'UPDATE sources SET status = ?, updated_at = ?, last_synced_at = ? WHERE id = ?',
        [documents.isNotEmpty ? 'ready' : 'empty', now, now, sourceId],
      );
      db.execute('COMMIT');

      insertDoc.dispose();
      insertChunk.dispose();
      insertFts.dispose();
      insertTrigram.dispose();
    } catch (e) {
      db.execute('ROLLBACK');
      _touchSource(sourceId, 'error', null);
      rethrow;
    }

    return {
      'documentCount': documents.length,
      'chunkCount': chunksToInsert.length,
      'skippedFiles': skippedFiles,
    };
  }

  @override
  Future<List<RagSearchResult>> searchSource(String sourceId, String query, {int limit = 8}) async {
    _requireSource(sourceId);
    final effectiveLimit = max(1, min(limit, 25));
    
    // Prepare search variations for better Japanese text matching
    final searchVariations = _prepareSearchVariations(query);
    final db = _ragDb.db;

    var rows = <Row>[];

    // Try each search variation until we get results
    for (final variation in searchVariations) {
      final ftsQuery = toFtsQuery(variation);
      
      if (ftsQuery.isNotEmpty) {
        try {
          rows = db.select('''
            SELECT chunk_id, document_id, rel_path, heading, content,
                   bm25(chunks_fts, 8.0, 5.0, 1.0) AS rank
            FROM chunks_fts
            WHERE chunks_fts MATCH ? AND source_id = ?
            ORDER BY rank ASC
            LIMIT ?
          ''', [ftsQuery, sourceId, effectiveLimit]);
          
          if (rows.isNotEmpty) break; // Found results, stop trying variations
        } catch (_) {
          rows = [];
        }
      }
    }

    // Tier 2: trigram FTS (CJK fallback) with variations
    if (rows.isEmpty) {
      for (final variation in searchVariations) {
        final trigramQuery = variation.trim();
        if (trigramQuery.isEmpty) continue;
        
        try {
          rows = db.select('''
            SELECT chunk_id, document_id, rel_path, heading, content,
                   bm25(chunks_trigram, 8.0, 5.0, 1.0) AS rank
            FROM chunks_trigram
            WHERE chunks_trigram MATCH ? AND source_id = ?
            ORDER BY rank ASC
            LIMIT ?
          ''', [trigramQuery, sourceId, effectiveLimit]);
          
          if (rows.isNotEmpty) break; // Found results, stop trying variations
        } catch (_) {
          continue;
        }
      }
    }

    // Tier 3: LIKE fallback with variations
    if (rows.isEmpty) {
      for (final variation in searchVariations) {
        final likeQuery = '%$variation%';
        try {
          rows = db.select('''
            SELECT chunk_id, document_id, rel_path, heading, content, 0 AS rank
            FROM chunks
            WHERE content LIKE ? AND source_id = ?
            LIMIT ?
          ''', [likeQuery, sourceId, effectiveLimit]);
          
          if (rows.isNotEmpty) break; // Found results, stop trying variations
        } catch (_) {
          continue;
        }
      }
    }

    return rows
        .map((row) => RagSearchResult(
          chunkId: row.readText('chunk_id'),
          documentId: row.readText('document_id'),
          relPath: row.readText('rel_path'),
          heading: row.readText('heading'),
          content: row.readText('content'),
          score: row.readReal('rank'),
        ))
        .toList();
  }

  /// Prepare search query variations for better Japanese text matching
  List<String> _prepareSearchVariations(String query) {
    final variations = <String>{query};
    
    // Add hiragana to katakana and vice versa
    variations.add(_hiraganaToKatakana(query));
    variations.add(_katakanaToHiragana(query));
    
    // Add normalized version (NFKC)
    variations.add(query.normalize(NormalizationForm.nfkc));
    
    // Add half-width to full-width conversions
    variations.add(_halfWidthToFullWidth(query));
    variations.add(_fullWidthToHalfWidth(query));
    
    // Remove common punctuation variations
    variations.add(query.replaceAll(RegExp(r'[、。！？]'), ''));
    
    return variations.where((v) => v.isNotEmpty).toList();
  }

  /// Convert hiragana to katakana
  String _hiraganaToKatakana(String text) {
    return text.replaceAllMapped(RegExp(r'[\u3041-\u3096]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      return String.fromCharCode(code + 0x60);
    });
  }

  /// Convert katakana to hiragana  
  String _katakanaToHiragana(String text) {
    return text.replaceAllMapped(RegExp(r'[\u30A1-\u30F6]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      return String.fromCharCode(code - 0x60);
    });
  }

  /// Convert half-width to full-width characters
  String _halfWidthToFullWidth(String text) {
    return text.replaceAllMapped(RegExp(r'[\u0021-\u007E]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      if (code >= 0x21 && code <= 0x7E) {
        return String.fromCharCode(code + 0xFEE0);
      }
      return match.group(0)!;
    });
  }

  /// Convert full-width to half-width characters
  String _fullWidthToHalfWidth(String text) {
    return text.replaceAllMapped(RegExp(r'[\uFF01-\uFF5E]'), (match) {
      final code = match.group(0)!.codeUnitAt(0);
      if (code >= 0xFF01 && code <= 0xFF5E) {
        return String.fromCharCode(code - 0xFEE0);
      }
      return match.group(0)!;
    });
  }
            WHERE chunks_trigram MATCH ? AND source_id = ?
            ORDER BY rank ASC
            LIMIT ?
          ''', [escaped, sourceId, effectiveLimit]);
        } catch (_) {
          rows = [];
        }
      }
    }

    // Tier 3: LIKE fallback
    if (rows.isEmpty) {
      rows = db.select('''
        SELECT c.id AS chunk_id, c.document_id, c.rel_path, c.heading, c.content,
               1.0 AS rank
        FROM chunks c
        WHERE c.source_id = ? AND lower(c.content) LIKE '%' || lower(?) || '%'
        ORDER BY c.rel_path ASC, c.chunk_index ASC
        LIMIT ?
      ''', [sourceId, query.trim(), effectiveLimit]);
    }

    return rows.map((Row row) {
      final rank = (row['rank'] as num?)?.toDouble() ?? 1.0;
      final score = max(0, (100 - rank * 10).round());
      final content = (row['content'] ?? '') as String;
      return RagSearchResult(
        chunkId: (row['chunk_id'] ?? '') as String,
        documentId: (row['document_id'] ?? '') as String,
        relPath: (row['rel_path'] ?? '') as String,
        heading: row['heading'] as String?,
        content: content,
        excerpt: buildExcerpt(content, query),
        score: score,
      );
    }).toList();
  }

  @override
  Future<RagAnswer> answerSource(String sourceId, String question, {int limit = 5}) async {
    final results = await searchSource(sourceId, question, limit: limit);
    if (results.isEmpty) {
      return RagAnswer(
        question: question,
        answer: 'No matching indexed passages were found in the local store.',
        citations: [],
      );
    }

    final topResults = results.take(min(3, results.length)).toList();
    final answerLines = topResults.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      final heading = r.heading != null ? ' (${r.heading})' : '';
      return '${i + 1}. ${r.excerpt} [${r.relPath}$heading]';
    });

    return RagAnswer(
      question: question,
      answer: ['Local answer draft based on indexed passages:', ...answerLines].join('\n'),
      citations: topResults
          .map((r) => RagCitation(chunkId: r.chunkId, relPath: r.relPath, heading: r.heading))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchDocument(String sourceId, String documentId) async {
    _requireSource(sourceId);
    final rows = _ragDb.db.select(
      'SELECT id, rel_path, plain_text FROM documents WHERE source_id = ? AND id = ? LIMIT 1',
      [sourceId, documentId],
    );

    if (rows.isEmpty) throw Exception('Document not found');

    final Row row = rows.first;
    return {
      'documentId': row['id'] as String?,
      'relPath': row['rel_path'] as String?,
      'content': row['plain_text'] as String?,
    };
  }

  // Schedule methods — not supported on local/mobile mode
  @override
  Future<List<SyncSchedule>> listSchedules() async => [];

  @override
  Future<SyncSchedule?> getSchedule(String sourceId) async => null;

  @override
  Future<SyncSchedule> upsertSchedule(String sourceId, String frequency, String timezone, bool enabled) async {
    throw UnsupportedError('Sync schedules are not supported in local mode');
  }

  @override
  Future<void> deleteScheduleForSource(String sourceId) async {}

  // --- Private helpers ---

  RagSource _mapSourceRow(Map<String, dynamic> row) {
    return RagSource(
      sourceId: (row['id'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      status: (row['status'] ?? 'empty') as String,
      sourceType: (row['source_type'] ?? 'uploaded_documents') as String,
      documentCount: (row['document_count'] as int?) ?? 0,
      chunkCount: (row['chunk_count'] as int?) ?? 0,
      createdAt: (row['created_at'] ?? '') as String,
      updatedAt: (row['updated_at'] ?? '') as String,
      lastSyncedAt: row['last_synced_at'] as String?,
    );
  }

  RagSource _requireSource(String sourceId) {
    final rows = _ragDb.db.select('''
      SELECT s.id, s.name, s.status, s.source_type, s.created_at, s.updated_at, s.last_synced_at,
        COALESCE((SELECT COUNT(*) FROM documents d WHERE d.source_id = s.id), 0) AS document_count,
        COALESCE((SELECT COUNT(*) FROM chunks c WHERE c.source_id = s.id), 0) AS chunk_count
      FROM sources s WHERE s.id = ? LIMIT 1
    ''', [sourceId]);

    if (rows.isEmpty) throw Exception('Unknown source: $sourceId');
    return _mapSourceRow(rows.first);
  }

  void _touchSource(String sourceId, String status, String? lastSyncedAt) {
    _ragDb.db.execute(
      'UPDATE sources SET status = ?, updated_at = ?, last_synced_at = ? WHERE id = ?',
      [status, DateTime.now().toUtc().toIso8601String(), lastSyncedAt, sourceId],
    );
  }

  bool _isUnsupportedFile(File file) {
    final fileName = file.path.toLowerCase();
    const unsupported = [
      '.gsheet', '.gdoc', '.gslides', '.gdraw', '.gform', '.gsite',
      '.lnk', '.tmp', '.temp', '.cache', '.log',
      '.exe', '.dll', '.sys', '.bat', '.cmd', '.ps1',
      '.msi', '.deb', '.rpm', '.dmg', '.app',
    ];

    if (unsupported.any((ext) => fileName.endsWith(ext))) return true;

    final fileNameOnly = p.basename(file.path);
    if (fileNameOnly.startsWith('.')) return true;

    return false;
  }

  String _sanitizeRelativePath(String value) {
    return value
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty && s != '.' && s != '..')
        .join('/');
  }

  Future<List<String>> _walkFiles(String rootDir) async {
    final dir = Directory(rootDir);
    if (!dir.existsSync()) return [];

    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      if (p.basename(entity.path).startsWith('.')) continue;
      final stat = entity.statSync();
      if (stat.size > 10 * 1024 * 1024) continue;
      files.add(entity.path);
    }

    return files;
  }
}
