import 'dart:io';

import '../models/rag_source.dart';
import '../models/sync_schedule.dart';

abstract class RagServiceInterface {
  Future<Map<String, dynamic>> fetchHealth();
  Future<List<RagSource>> fetchSources();
  Future<RagSource> createSource(String name);
  Future<void> deleteSource(String sourceId);
  Future<RagSource> renameSource(String sourceId, String name);
  Future<void> uploadFiles(String sourceId, List<File> files, {String? basePath});
  Future<Map<String, dynamic>> syncSource(String sourceId);
  Future<List<RagSearchResult>> searchSource(String sourceId, String query, {int limit = 8});
  Future<RagAnswer> answerSource(String sourceId, String question, {int limit = 5});
  Future<Map<String, dynamic>> fetchDocument(String sourceId, String documentId);
  Future<List<SyncSchedule>> listSchedules();
  Future<SyncSchedule?> getSchedule(String sourceId);
  Future<SyncSchedule> upsertSchedule(String sourceId, String frequency, String timezone, bool enabled);
  Future<void> deleteScheduleForSource(String sourceId);
}
