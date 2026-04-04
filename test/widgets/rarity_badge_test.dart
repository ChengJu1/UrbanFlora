import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_flora/core/models/species.dart';
import 'package:urban_flora/shared/widgets/rarity_badge.dart';

void main() {
  testWidgets('RarityBadge renders each tier label', (tester) async {
    for (final r in Rarity.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RarityBadge(rarity: r)),
        ),
      );
      expect(find.text(r.label), findsOneWidget);
    }
  });
}
