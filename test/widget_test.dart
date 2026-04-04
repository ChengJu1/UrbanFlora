import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_flora/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme builds without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: Text('UrbanFlora'))),
      ),
    );
    expect(find.text('UrbanFlora'), findsOneWidget);
  });
}
