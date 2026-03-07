import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/rag_source.dart';

class RagSourceService {
  final String baseUrl;

  RagSourceService({
    required this.baseUrl,
  });

  String get _normalizedBaseUrl => baseUrl.replaceAll(RegExp(r"/+$"), "");

  Uri _uri(String path) => Uri.parse("$_normalizedBaseUrl$path");

  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await http.get(_uri("/health"));
    _throwIfNeeded(response);

    final payload = json.decode(response.body);
    return Map<String, dynamic>.from(payload["data"] as Map);
  }

  Future<List<RagSource>> fetchSources() async {
    final response = await http.get(_uri("/rag/sources"));
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

  Future<RagSource> createSource(String name) async {
    final response = await http.post(
      _uri("/rag/sources"),
      headers: _jsonHeaders,
      body: json.encode({"name": name}),
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
    }

    final response = await http.post(
      _uri("/rag/sources/$sourceId/files"),
      headers: _jsonHeaders,
      body: json.encode({"files": filePayloads}),
    );
    _throwIfNeeded(response);
  }

  Future<Map<String, dynamic>> syncSource(String sourceId) async {
    final response = await http.post(
      _uri("/rag/sources/$sourceId/sync"),
      headers: _jsonHeaders,
      body: json.encode({}),
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
    final response = await http.post(
      _uri("/rag/sources/$sourceId/search"),
      headers: _jsonHeaders,
      body: json.encode({
        "query": query,
        "limit": limit,
      }),
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
    final response = await http.post(
      _uri("/rag/sources/$sourceId/answer"),
      headers: _jsonHeaders,
      body: json.encode({
        "question": question,
        "limit": limit,
      }),
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
}
