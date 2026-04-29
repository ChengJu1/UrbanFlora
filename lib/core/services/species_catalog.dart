import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/species.dart';

/// Reads the bundled species seed and answers rarity lookups.
///
/// Call `load()` once at startup; afterwards `instance` is safe to read
/// from anywhere synchronously.
class SpeciesCatalog {
  SpeciesCatalog._(this._byScientific, this._byGenus, this._byFamily);

  final Map<String, Rarity> _byScientific;
  final Map<String, Rarity> _byGenus;
  final Map<String, Rarity> _byFamily;

  static SpeciesCatalog _instance =
      SpeciesCatalog._(const {}, const {}, const {});

  static SpeciesCatalog get instance => _instance;

  /// Reads assets/seed/species_seed.json and caches it.
  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/seed/species_seed.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    final byScientific = <String, Rarity>{};
    final byGenus = <String, Rarity>{};
    final familyHits = <String, Map<Rarity, int>>{};

    for (final row in list) {
      final sci = (row['scientificName'] as String? ?? '').trim().toLowerCase();
      final family = (row['family'] as String? ?? '').trim().toLowerCase();
      final tier = _parseRarity(row['rarity'] as String?);
      if (sci.isEmpty) continue;
      byScientific[sci] = tier;

      // genus is the first word of the scientific name
      final genus = sci.split(' ').first;
      final existingGenus = byGenus[genus];
      if (existingGenus == null || tier.index < existingGenus.index) {
        byGenus[genus] = tier;
      }

      if (family.isNotEmpty) {
        final hits = familyHits[family] ??= <Rarity, int>{};
        hits[tier] = (hits[tier] ?? 0) + 1;
      }
    }

    // for the family fallback, pick the rarity that shows up the most
    final byFamily = <String, Rarity>{};
    familyHits.forEach((family, hits) {
      final top = hits.entries.reduce((a, b) => a.value >= b.value ? a : b);
      byFamily[family] = top.key;
    });

    _instance = SpeciesCatalog._(byScientific, byGenus, byFamily);
  }

  /// Tries the exact name, then the genus, then the family.
  /// Falls back to common when nothing matches.
  Rarity rarityFor({String? scientificName, String? family}) {
    final sci = scientificName?.trim().toLowerCase();
    if (sci != null && sci.isNotEmpty) {
      final exact = _byScientific[sci];
      if (exact != null) return exact;
      final genus = sci.split(' ').first;
      final byGenus = _byGenus[genus];
      if (byGenus != null) return byGenus;
    }
    final fam = family?.trim().toLowerCase();
    if (fam != null && fam.isNotEmpty) {
      final byFam = _byFamily[fam];
      if (byFam != null) return byFam;
    }
    return Rarity.common;
  }

  static Rarity _parseRarity(String? s) {
    switch (s?.toLowerCase()) {
      case 'uncommon':
        return Rarity.uncommon;
      case 'rare':
        return Rarity.rare;
      case 'legendary':
        return Rarity.legendary;
      default:
        return Rarity.common;
    }
  }
}
