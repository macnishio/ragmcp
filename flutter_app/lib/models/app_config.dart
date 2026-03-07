class AppConfig {
  final String serverUrl;
  final bool isEmbeddedServer;
  final bool useExternalServer;

  const AppConfig({
    this.serverUrl = "http://127.0.0.1:3001",
    this.isEmbeddedServer = false,
    this.useExternalServer = false,
  });

  AppConfig copyWith({
    String? serverUrl,
    bool? isEmbeddedServer,
    bool? useExternalServer,
  }) {
    return AppConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      isEmbeddedServer: isEmbeddedServer ?? this.isEmbeddedServer,
      useExternalServer: useExternalServer ?? this.useExternalServer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "serverUrl": serverUrl,
      "isEmbeddedServer": isEmbeddedServer,
      "useExternalServer": useExternalServer,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      serverUrl: (json["serverUrl"] ?? "http://127.0.0.1:3001").toString(),
      isEmbeddedServer: json["isEmbeddedServer"] == true,
      useExternalServer: json["useExternalServer"] == true,
    );
  }
}
