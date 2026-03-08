import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/app_config.dart';
import 'local_rag_service.dart';
import 'rag_service_interface.dart';
import 'rag_source_service.dart';

class RagServiceFactory {
  static Future<RagServiceInterface> create(AppConfig config) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final appDir = await getApplicationDocumentsDirectory();
      return LocalRagService.open(appDir.path);
    }
    return RagSourceService(baseUrl: config.serverUrl);
  }
}
