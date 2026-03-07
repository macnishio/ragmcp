class RagSource {
  final String sourceId;
  final String name;
  final String status;
  final String sourceType;
  final int documentCount;
  final int chunkCount;
  final String createdAt;
  final String updatedAt;
  final String? lastSyncedAt;

  const RagSource({
    required this.sourceId,
    required this.name,
    required this.status,
    required this.sourceType,
    required this.documentCount,
    required this.chunkCount,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSyncedAt,
  });

  factory RagSource.fromJson(Map<String, dynamic> json) {
    return RagSource(
      sourceId: (json["sourceId"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      status: (json["status"] ?? "empty").toString(),
      sourceType: (json["sourceType"] ?? "uploaded_documents").toString(),
      documentCount: _toInt(json["documentCount"]),
      chunkCount: _toInt(json["chunkCount"]),
      createdAt: (json["createdAt"] ?? "").toString(),
      updatedAt: (json["updatedAt"] ?? "").toString(),
      lastSyncedAt: json["lastSyncedAt"]?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }
}

class RagSearchResult {
  final String chunkId;
  final String documentId;
  final String relPath;
  final String? heading;
  final String content;
  final String excerpt;
  final int score;

  const RagSearchResult({
    required this.chunkId,
    required this.documentId,
    required this.relPath,
    required this.heading,
    required this.content,
    required this.excerpt,
    required this.score,
  });

  factory RagSearchResult.fromJson(Map<String, dynamic> json) {
    return RagSearchResult(
      chunkId: (json["chunkId"] ?? "").toString(),
      documentId: (json["documentId"] ?? "").toString(),
      relPath: (json["relPath"] ?? "").toString(),
      heading: json["heading"]?.toString(),
      content: (json["content"] ?? "").toString(),
      excerpt: (json["excerpt"] ?? "").toString(),
      score: RagSource._toInt(json["score"]),
    );
  }
}

class RagAnswer {
  final String question;
  final String answer;
  final List<RagCitation> citations;

  const RagAnswer({
    required this.question,
    required this.answer,
    required this.citations,
  });

  factory RagAnswer.fromJson(Map<String, dynamic> json) {
    final rawCitations = json["citations"];
    final citations = rawCitations is List
        ? rawCitations
            .whereType<Map>()
            .map((item) => RagCitation.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <RagCitation>[];

    return RagAnswer(
      question: (json["question"] ?? "").toString(),
      answer: (json["answer"] ?? "").toString(),
      citations: citations,
    );
  }
}

class RagCitation {
  final String chunkId;
  final String relPath;
  final String? heading;

  const RagCitation({
    required this.chunkId,
    required this.relPath,
    required this.heading,
  });

  factory RagCitation.fromJson(Map<String, dynamic> json) {
    return RagCitation(
      chunkId: (json["chunkId"] ?? "").toString(),
      relPath: (json["relPath"] ?? "").toString(),
      heading: json["heading"]?.toString(),
    );
  }
}
