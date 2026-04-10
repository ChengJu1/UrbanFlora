import '../../core/models/observation.dart';

/// A botanical family with all the species the user has collected from it,
/// plus how many empty "locked" slots are left to fill out a tile of 6.
class FamilyGroup {
  FamilyGroup({required this.family, required this.observations});

  final String family;
  final List<Observation> observations;

  static const int slotsPerFamily = 6;

  int get lockedSlots {
    final remaining = slotsPerFamily - observations.length;
    return remaining.clamp(0, slotsPerFamily);
  }
}

/// Group observations by family and dedupe by species. Sorted alphabetically.
List<FamilyGroup> groupByFamily(List<Observation> all) {
  final byFamily = <String, Map<String, Observation>>{};
  for (final o in all) {
    final fam = o.chosenSpecies.family;
    final key = o.chosenSpecies.scientificName;
    byFamily.putIfAbsent(fam, () => {}).putIfAbsent(key, () => o);
  }
  return byFamily.entries
      .map((e) => FamilyGroup(
            family: e.key,
            observations: e.value.values.toList(),
          ))
      .toList()
    ..sort((a, b) => a.family.compareTo(b.family));
}
