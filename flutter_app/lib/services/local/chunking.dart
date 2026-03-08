import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'constants.dart';

class ChunkRecord {
  final String chunkId;
  final String sourceId;
  final String documentId;
  final String relPath;
  final int chunkIndex;
  final String? heading;
  final String content;
  final String contentHash;

  const ChunkRecord({
    required this.chunkId,
    required this.sourceId,
    required this.documentId,
    required this.relPath,
    required this.chunkIndex,
    required this.heading,
    required this.content,
    required this.contentHash,
  });
}

String normalizeText(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\t', '  ')
      .replaceAllMapped(RegExp(r'\n{3,}'), (_) => '\n\n')
      .trim();
}

List<String> _splitLongBlock(String block, int maxChars) {
  final slices = <String>[];
  var current = block.trim();

  while (current.length > maxChars) {
    var splitAt = current.lastIndexOf('. ', maxChars);
    if (splitAt < maxChars ~/ 2) {
      splitAt = current.lastIndexOf('\n', maxChars);
    }
    if (splitAt < maxChars ~/ 2) {
      splitAt = maxChars;
    }
    slices.add(current.substring(0, splitAt).trim());
    current = current.substring(splitAt).trim();
  }

  if (current.isNotEmpty) {
    slices.add(current);
  }

  return slices;
}

String? _detectHeading(String content) {
  final firstLine = content.split('\n').first.trim();
  if (firstLine.isEmpty) return null;

  if (firstLine.startsWith('#')) {
    return firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  }

  if (firstLine.length <= 80) {
    return firstLine;
  }

  return null;
}

List<ChunkRecord> buildChunks({
  required String sourceId,
  required String documentId,
  required String relPath,
  required String plainText,
}) {
  final normalized = normalizeText(plainText);
  if (normalized.isEmpty) return [];

  final paragraphs = normalized
      .split(RegExp(r'\n\s*\n'))
      .expand((paragraph) => paragraph.length > maxChunkChars
          ? _splitLongBlock(paragraph, maxChunkChars)
          : [paragraph.trim()])
      .where((s) => s.isNotEmpty)
      .toList();

  final chunks = <ChunkRecord>[];
  var current = '';

  for (final paragraph in paragraphs) {
    final candidate = current.isEmpty ? paragraph : '$current\n\n$paragraph';
    if (candidate.length <= maxChunkChars) {
      current = candidate;
      continue;
    }

    if (current.isNotEmpty) {
      chunks.add(_createChunk(sourceId, documentId, relPath, chunks.length, current));
    }
    current = paragraph;
  }

  if (current.isNotEmpty) {
    chunks.add(_createChunk(sourceId, documentId, relPath, chunks.length, current));
  }

  return chunks;
}

ChunkRecord _createChunk(
  String sourceId,
  String documentId,
  String relPath,
  int chunkIndex,
  String content,
) {
  final hashBytes = utf8.encode('$relPath\n$content');
  final contentHash = sha256.convert(hashBytes).toString();

  return ChunkRecord(
    chunkId: '$documentId:chunk:$chunkIndex',
    sourceId: sourceId,
    documentId: documentId,
    relPath: relPath,
    chunkIndex: chunkIndex,
    heading: _detectHeading(content),
    content: content,
    contentHash: contentHash,
  );
}
