import 'package:flutter_test/flutter_test.dart';
import 'package:urban_flora/core/models/species.dart';

void main() {
  group('SpeciesCandidate.fromPlantNet', () {
    test('parses a typical Pl@ntNet payload', () {
      final parsed = SpeciesCandidate.fromPlantNet({
        'score': 0.88,
        'species': {
          'scientificNameWithoutAuthor': 'Bellis perennis',
          'commonNames': ['Common daisy', 'English daisy'],
          'family': {'scientificNameWithoutAuthor': 'Asteraceae'},
          'genus': {'scientificNameWithoutAuthor': 'Bellis'},
        },
      });

      expect(parsed.scientificName, 'Bellis perennis');
      expect(parsed.commonName, 'Common daisy');
      expect(parsed.family, 'Asteraceae');
      expect(parsed.genus, 'Bellis');
      expect(parsed.score, closeTo(0.88, 0.0001));
      expect(parsed.rarity, Rarity.common);
    });

    test('falls back when fields are missing', () {
      final parsed = SpeciesCandidate.fromPlantNet(const {});
      expect(parsed.scientificName, 'Unknown');
      expect(parsed.family, 'Unknown family');
      expect(parsed.score, 0);
      expect(parsed.rarity, Rarity.legendary);
    });
  });
}
