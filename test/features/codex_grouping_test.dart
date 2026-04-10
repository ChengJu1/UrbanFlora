import 'package:flutter_test/flutter_test.dart';
import 'package:urban_flora/core/models/observation.dart';
import 'package:urban_flora/core/models/species.dart';
import 'package:urban_flora/features/codex/codex_grouping.dart';

Observation _obs({
  required String id,
  required String family,
  required String sciName,
  String? common,
  double score = 0.8,
}) {
  final candidate = SpeciesCandidate(
    scientificName: sciName,
    commonName: common ?? sciName,
    family: family,
    score: score,
  );
  return Observation(
    id: id,
    userId: 'u1',
    photoUrl: '',
    thumbUrl: '',
    capturedAt: DateTime(2026, 1, 1),
    candidates: [candidate],
    chosenSpecies: candidate,
  );
}

void main() {
  group('groupByFamily', () {
    test('groups observations by family and sorts alphabetically', () {
      final result = groupByFamily([
        _obs(id: '1', family: 'Fabaceae', sciName: 'Trifolium repens'),
        _obs(id: '2', family: 'Asteraceae', sciName: 'Bellis perennis'),
        _obs(id: '3', family: 'Asteraceae', sciName: 'Taraxacum officinale'),
      ]);
      expect(result.map((g) => g.family).toList(),
          ['Asteraceae', 'Fabaceae']);
      expect(result.first.observations.length, 2);
    });

    test('deduplicates by scientific name, keeping first occurrence', () {
      final result = groupByFamily([
        _obs(id: '1', family: 'Asteraceae', sciName: 'Bellis perennis'),
        _obs(id: '2', family: 'Asteraceae', sciName: 'Bellis perennis'),
      ]);
      expect(result.single.observations.length, 1);
      expect(result.single.observations.single.id, '1');
    });

    test('lockedSlots pads out a family to 6 visible tiles', () {
      final result = groupByFamily([
        _obs(id: '1', family: 'Asteraceae', sciName: 'Bellis perennis'),
      ]);
      expect(result.single.lockedSlots, 5);
    });

    test('lockedSlots never goes negative when overfull', () {
      final entries = List.generate(
        8,
        (i) => _obs(id: '$i', family: 'Fabaceae', sciName: 'Species$i'),
      );
      final result = groupByFamily(entries);
      expect(result.single.lockedSlots, 0);
    });

    test('empty input yields empty list', () {
      expect(groupByFamily(const []), isEmpty);
    });
  });
}
