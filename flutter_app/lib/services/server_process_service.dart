import 'dart:io';

import 'package:http/http.dart' as http;

class ServerProcessService {
  Process? _process;
  int? _port;
  bool _started = false;

  int? get port => _port;
  bool get isRunning => _started && _process != null;
  String get serverUrl => 'http://127.0.0.1:${_port ?? 3001}';

  /// Find the embedded SEA server binary path.
  /// Returns null if not found (e.g., running in debug mode without bundled binary).
  String? _findServerBinary() {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    if (Platform.isWindows) {
      final path = '$exeDir/data/ragmcp-server-win32-x64.exe';
      if (File(path).existsSync()) return path;
    } else if (Platform.isMacOS) {
      // In macOS .app bundle: Contents/MacOS/flutter_app -> Contents/Resources/
      final appDir = File(exePath).parent.parent.path;
      final path = '$appDir/Resources/ragmcp-server-darwin-arm64';
      if (File(path).existsSync()) return path;
      // Also check next to executable for dev builds
      final devPath = '$exeDir/ragmcp-server-darwin-arm64';
      if (File(devPath).existsSync()) return devPath;
    } else if (Platform.isLinux) {
      final path = '$exeDir/data/ragmcp-server-linux-x64';
      if (File(path).existsSync()) return path;
    }

    return null;
  }

  /// Find a free port by binding to port 0.
  Future<int> _findFreePort() async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    final port = server.port;
    await server.close();
    return port;
  }

  /// Start the embedded server. Returns the server URL on success.
  /// Returns null if no embedded binary is found.
  Future<String?> startServer() async {
    if (_started) return serverUrl;

    final binaryPath = _findServerBinary();
    if (binaryPath == null) return null;

    _port = await _findFreePort();

    _process = await Process.start(
      binaryPath,
      [],
      environment: {
        'PORT': _port.toString(),
        'HOST': '127.0.0.1',
      },
    );

    // Forward server stderr to console for debugging
    _process!.stderr.listen((data) {
      // ignore
    });
    _process!.stdout.listen((data) {
      // ignore
    });

    // Wait for server to be ready (up to 15 seconds)
    final ok = await _waitForHealth();
    if (ok) {
      _started = true;
      return serverUrl;
    } else {
      stopServer();
      return null;
    }
  }

  Future<bool> _waitForHealth() async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final response = await http.get(
          Uri.parse('$serverUrl/health'),
        ).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) return true;
      } catch (_) {
        // Server not ready yet
      }
    }
    return false;
  }

  void stopServer() {
    _process?.kill();
    _process = null;
    _started = false;
  }
}
