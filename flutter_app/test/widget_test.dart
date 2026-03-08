import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:flutter_app/models/app_config.dart';
import 'package:flutter_app/screens/settings_screen.dart';

void main() {
  testWidgets('renders settings form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          initialConfig: const AppConfig(),
          onSaved: (_) async {},
        ),
      ),
    );

    expect(find.text('Settings'), findsWidgets);
    
    // 外部サーバートグルをオンにする
    await tester.tap(find.byType(Switch));
    await tester.pump();
    
    expect(find.text('Server URL'), findsOneWidget);
  });
}
