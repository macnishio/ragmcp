import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/rag_source.dart';
import '../models/sync_schedule.dart';
import 'rag_service_interface.dart';

/// RAGソースサービス - HTTPクライアント経由でRAGサーバーと通信
/// 
/// このサービスは以下の機能を提供します：
/// - RAGソースの作成、読み取り、更新、削除（CRUD）
/// - ファイルのアップロードと同期
/// - 検索と質問応答
/// - スケジュール管理
/// 
/// 使用例：
/// ```dart
/// final service = RagSourceService(baseUrl: 'http://127.0.0.1:3001');
/// final sources = await service.fetchSources();
/// ```
class RagSourceService implements RagServiceInterface {
  /// RAGサーバーのベースURL
  final String baseUrl;
  
  /// HTTPクライアントインスタンス
  final http.Client _client;

  /// RAGソースサービスを初期化
  /// 
  /// [baseUrl] RAGサーバーのベースURL（例: 'http://127.0.0.1:3001'）
  /// [client] カスタムHTTPクライアント（省略時はデフォルトクライアントを使用）
  RagSourceService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// 末尾のスラッシュを削除した正規化されたベースURLを取得
  String get _normalizedBaseUrl => baseUrl.replaceAll(RegExp(r"/+$"), "");

  /// ベースURLとパスを結合して完全なURIを生成
  /// 
  /// [path] サーバーのエンドポイントパス（例: '/health'）
  /// 完全なURIを返す
  Uri _uri(String path) => Uri.parse("$_normalizedBaseUrl$path");

  /// サーバーのヘルスチェックを実行
  /// 
  /// サーバーが正常に動作しているかを確認します。
  /// 10秒でタイムアウトし、タイムアウト時はHttpExceptionをスローします。
  /// 
  /// 戻り値: サーバー情報を含むMap
  /// 例外: HttpException - 接続タイムアウトまたはHTTPエラー時
  @override
  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await _client.get(_uri("/health")).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return Map<String, dynamic>.from(payload["data"] as Map);
  }

  @override
  Future<List<RagSource>> fetchSources() async {
    final response = await _retryWithBackoff(
      () => _client.get(_uri("/rag/sources")),
      maxRetries: 3,
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    final rawList = payload["data"];
    if (rawList is! List) {
      return [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => RagSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<http.Response> _retryWithBackoff(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    Exception? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await request().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw HttpException("Connection timeout"),
        );
        return response;
      } catch (e) {
        lastException = e as Exception;
        if (attempt == maxRetries) {
          break;
        }
        
        // 指数バックオフ
        final delay = initialDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }
    
    throw lastException ?? HttpException("Request failed after $maxRetries retries");
  }

  @override
  Future<RagSource> createSource(String name) async {
    final response = await _client.post(
      _uri("/rag/sources"),
      headers: _jsonHeaders,
      body: json.encode({"name": name}),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return RagSource.fromJson(Map<String, dynamic>.from(payload["data"] as Map));
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    final response = await _client.delete(
      _uri("/rag/sources/$sourceId"),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);
  }

  @override
  Future<RagSource> renameSource(String sourceId, String newName) async {
    final response = await _client.patch(
      _uri("/rag/sources/$sourceId"),
      headers: _jsonHeaders,
      body: json.encode({"name": newName}),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return RagSource.fromJson(Map<String, dynamic>.from(payload["data"] as Map));
  }

  @override
  Future<void> uploadFiles(
    String sourceId,
    List<File> files, {
    String? basePath,
  }) async {
    final filePayloads = <Map<String, String>>[];
    for (final file in files) {
      // Google Drive仮想ファイルとサポート外の拡張子を除外
      if (_isUnsupportedFile(file)) {
        continue;
      }
      
      try {
        final bytes = await file.readAsBytes();
        var fileName = file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
        if (basePath != null && file.path.startsWith(basePath)) {
          fileName = file.path.substring(basePath.length).replaceFirst(RegExp(r"^[\\\\/]+"), "");
        }
        filePayloads.add({
          "name": fileName,
          "content": base64Encode(bytes),
          "encoding": "base64",
        });
      } catch (e) {
        // ファイル読み込みエラーをスキップ
        final fileName = file.uri.pathSegments.last;
        if (e.toString().contains('FileSystemException')) {
          // 開発時のみデバッグ出力
          assert(false, 'Skipping unsupported file $fileName: Google Drive仮想ファイルまたはアクセス不可ファイル');
        } else {
          assert(false, 'Skipping file $fileName: $e');
        }
        continue;
      }
    }

    final response = await _client.post(
      _uri("/rag/sources/$sourceId/files"),
      headers: _jsonHeaders,
      body: json.encode({"files": filePayloads}),
    ).timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);
  }

  @override
  Future<Map<String, dynamic>> syncSource(String sourceId) async {
    final response = await _client.post(
      _uri("/rag/sources/$sourceId/sync"),
      headers: _jsonHeaders,
      body: json.encode({}),
    ).timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return Map<String, dynamic>.from(payload["data"] as Map);
  }

  @override

  @override
  Future<RagAnswer> answerSource(
    String sourceId,
    String question, {
    int limit = 5,
  }) async {
    final response = await _client.post(
      _uri("/rag/sources/$sourceId/answer"),
      headers: _jsonHeaders,
      body: json.encode({
        "question": question,
        "limit": limit,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return RagAnswer.fromJson(Map<String, dynamic>.from(payload["data"] as Map));
  }

  @override
  Future<List<SyncSchedule>> listSchedules() async {
    final response = await _client.get(_uri("/rag/schedules")).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    final rawList = payload["data"];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((item) => SyncSchedule.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<SyncSchedule?> getSchedule(String sourceId) async {
    final response = await _client.get(
      _uri("/rag/sources/$sourceId/schedule"),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    if (response.statusCode == 404) return null;
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return SyncSchedule.fromJson(Map<String, dynamic>.from(payload["data"] as Map));
  }

  @override
  Future<SyncSchedule> upsertSchedule(
    String sourceId,
    String frequency,
    String timezone,
    bool enabled,
  ) async {
    final response = await _client.put(
      _uri("/rag/sources/$sourceId/schedule"),
      headers: _jsonHeaders,
      body: json.encode({
        "frequency": frequency,
        "timezone": timezone,
        "enabled": enabled,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return SyncSchedule.fromJson(Map<String, dynamic>.from(payload["data"] as Map));
  }

  @override
  Future<void> deleteScheduleForSource(String sourceId) async {
    final response = await _client.delete(
      _uri("/rag/sources/$sourceId/schedule"),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);
  }

  @override
  Future<Map<String, dynamic>> fetchDocument(String sourceId, String documentId) async {
    final response = await _client.get(
      _uri("/rag/sources/$sourceId/documents/$documentId"),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return Map<String, dynamic>.from(payload["data"] as Map);
  }

  Map<String, String> get _jsonHeaders => const {
        "Content-Type": "application/json",
      };

  void _throwIfNeeded(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw HttpException("HTTP ${response.statusCode}: ${response.body}");
  }

  // サポート外のファイルをチェック
  bool _isUnsupportedFile(File file) {
    final fileName = file.path.toLowerCase();
    final unsupportedExtensions = [
      '.gsheet', '.gdoc', '.gslides', '.gdraw', '.gform', '.gsite',
      '.lnk', '.tmp', '.temp', '.cache', '.log',
      '.exe', '.dll', '.sys', '.bat', '.cmd', '.ps1',
      '.msi', '.deb', '.rpm', '.dmg', '.app',
    ];
    
    // Google Drive仮想ファイルをチェック
    if (fileName.contains('google drive') || 
        fileName.startsWith('g:\\') ||
        unsupportedExtensions.any((ext) => fileName.endsWith(ext))) {
      return true;
    }
    
    // 隠しファイルをチェック
    final fileNameOnly = file.uri.pathSegments.last;
    if (fileNameOnly.startsWith('.')) {
      return true;
    }
    
    return false;
  }
}
