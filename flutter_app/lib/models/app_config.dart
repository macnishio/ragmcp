class AppConfig {
  final String serverUrl;

  const AppConfig({
    this.serverUrl = "http://127.0.0.1:3001",
  });

  AppConfig copyWith({
    String? serverUrl,
  }) {
    return AppConfig(
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "serverUrl": serverUrl,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      serverUrl: (json["serverUrl"] ?? "http://127.0.0.1:3001").toString(),
    );
  }
}
