/// Rarity tiers used by badges and pin colours.
enum Rarity { common, uncommon, rare, legendary }

extension RarityX on Rarity {
  String get label => switch (this) {
        Rarity.common => 'Common',
        Rarity.uncommon => 'Uncommon',
        Rarity.rare => 'Rare',
        Rarity.legendary => 'Legendary',
      };

  int get colorValue => switch (this) {
        Rarity.common => 0xFF7BAE7F,
        Rarity.uncommon => 0xFF4A90E2,
        Rarity.rare => 0xFFB06BD6,
        Rarity.legendary => 0xFFE2A93B,
      };
}

/// One species guess returned by Pl@ntNet.
class SpeciesCandidate {
  const SpeciesCandidate({
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.score,
    this.genus,
  });

  final String scientificName;
  final String commonName;
  final String family;
  final String? genus;
  final double score;

  factory SpeciesCandidate.fromPlantNet(Map<String, dynamic> json) {
    final species = (json['species'] as Map<String, dynamic>?) ?? const {};
    final commons = (species['commonNames'] as List?)?.cast<String>() ?? const [];
    return SpeciesCandidate(
      scientificName: (species['scientificNameWithoutAuthor'] as String?) ??
          (species['scientificName'] as String?) ??
          'Unknown',
      commonName: commons.isNotEmpty ? commons.first : 'No common name',
      family:
          ((species['family'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor']
                  as String?) ??
              'Unknown family',
      genus: (species['genus'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor']
          as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'scientificName': scientificName,
        'commonName': commonName,
        'family': family,
        'genus': genus,
        'score': score,
      };

  factory SpeciesCandidate.fromMap(Map<String, dynamic> map) => SpeciesCandidate(
        scientificName: map['scientificName'] as String? ?? 'Unknown',
        commonName: map['commonName'] as String? ?? 'No common name',
        family: map['family'] as String? ?? 'Unknown',
        genus: map['genus'] as String?,
        score: (map['score'] as num?)?.toDouble() ?? 0,
      );

  // simple rule: low confidence = rare plant
  Rarity get rarity {
    if (score > 0.85) return Rarity.common;
    if (score > 0.6) return Rarity.uncommon;
    if (score > 0.35) return Rarity.rare;
    return Rarity.legendary;
  }
}
