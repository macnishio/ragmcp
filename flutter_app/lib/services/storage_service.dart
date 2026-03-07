import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';

class StorageService {
  static const String _configKey = "ragmcp_config";

  Future<AppConfig> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return const AppConfig();
    }

    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const AppConfig();
    }
    return AppConfig.fromJson(decoded);
  }

  Future<void> saveConfig(AppConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_configKey, json.encode(config.toJson()));
  }
}
