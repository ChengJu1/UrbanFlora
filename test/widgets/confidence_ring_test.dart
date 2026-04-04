import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_flora/shared/widgets/confidence_ring.dart';

void main() {
  testWidgets('ConfidenceRing renders a formatted percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ConfidenceRing(value: 0.42))),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('42%'), findsOneWidget);
  });
}
