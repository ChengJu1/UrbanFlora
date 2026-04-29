import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/species.dart';

/// Loads `assets/seed/species_seed.json` and answers rarity lookups.
///
/// Call [load] once during app startup before [runApp]; after that, the
/// rest of the app can read [instance] synchronously.
class SpeciesCatalog {
  SpeciesCatalog._(this._byScientific, this._byGenus, this._byFamily);

  // exact scientific name -> rarity (lower-cased keys)
  final Map<String, Rarity> _byScientific;

  // first word of the scientific name -> rarity, for genus fallback
  final Map<String, Rarity> _byGenus;

  // family name -> rarity, for the last-resort fallback
  final Map<String, Rarity> _byFamily;

  static SpeciesCatalog _instance =
      SpeciesCatalog._(const {}, const {}, const {});

  /// The currently loaded catalog (empty until [load] finishes).
  static SpeciesCatalog get instance => _instance;

  /// Reads the bundled seed file and caches it in [instance].
  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/seed/species_seed.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    final byScientific = <String, Rarity>{};
    final byGenus = <String, Rarity>{};
    // count rarities per family so we can pick the most common one
    final familyHits = <String, Map<Rarity, int>>{};

    for (final row in list) {
      final sci = (row['scientificName'] as String? ?? '').trim().toLowerCase();
      final family = (row['family'] as String? ?? '').trim().toLowerCase();
      final tier = _parseRarity(row['rarity'] as String?);
      if (sci.isEmpty) continue;
      byScientific[sci] = tier;

      // genus is the first word of the scientific name (e.g. "rosa" in
      // "Rosa canina"); we keep the lowest-rarity entry for the genus so
      // that genus fallback stays cautious instead of inflating tiers.
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

    final byFamily = <String, Rarity>{};
    familyHits.forEach((family, hits) {
      // pick whichever rarity appears most often inside this family
      final top = hits.entries.reduce((a, b) => a.value >= b.value ? a : b);
      byFamily[family] = top.key;
    });

    _instance = SpeciesCatalog._(byScientific, byGenus, byFamily);
  }

  /// Looks up a rarity tier.
  ///
  /// Tries (in order) the exact scientific name, the genus, then the
  /// family. Falls back to [Rarity.common] when nothing matches, since
  /// most plants you bump into in a city are common.
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
