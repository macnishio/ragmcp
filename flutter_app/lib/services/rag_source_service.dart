import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/rag_source.dart';

class RagSourceService {
  final String baseUrl;
  final http.Client _client;

  RagSourceService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String get _normalizedBaseUrl => baseUrl.replaceAll(RegExp(r"/+$"), "");

  Uri _uri(String path) => Uri.parse("$_normalizedBaseUrl$path");

  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await _client.get(_uri("/health")).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return Map<String, dynamic>.from(payload["data"] as Map);
  }

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
    http.Response? lastResponse;
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

  Future<void> deleteSource(String sourceId) async {
    final response = await _client.delete(
      _uri("/rag/sources/$sourceId"),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);
  }

  Future<RagSource> renameSource(String sourceId, String name) async {
    final response = await _client.patch(
      _uri("/rag/sources/$sourceId"),
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
          print('Skipping unsupported file ${fileName}: Google Drive仮想ファイルまたはアクセス不可ファイル');
        } else {
          print('Skipping file ${fileName}: $e');
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

  Future<List<RagSearchResult>> searchSource(
    String sourceId,
    String query, {
    int limit = 8,
  }) async {
    final response = await _client.post(
      _uri("/rag/sources/$sourceId/search"),
      headers: _jsonHeaders,
      body: json.encode({
        "query": query,
        "limit": limit,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw HttpException("Connection timeout"),
    );
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    final data = Map<String, dynamic>.from(payload["data"] as Map);
    final rawResults = data["results"];
    if (rawResults is! List) {
      return [];
    }

    return rawResults
        .whereType<Map>()
        .map((item) => RagSearchResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

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
