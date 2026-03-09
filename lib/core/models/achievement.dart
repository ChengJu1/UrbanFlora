/// One badge that can be unlocked by hitting a milestone.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
}

const List<Achievement> kAchievementCatalog = [
  Achievement(
    id: 'first_bloom',
    title: 'First Bloom',
    description: 'Record your very first observation.',
    icon: 'local_florist',
  ),
  Achievement(
    id: 'streak_3',
    title: 'Three-day Green Thumb',
    description: 'Observe on 3 consecutive days.',
    icon: 'whatshot',
  ),
  Achievement(
    id: 'ten_species',
    title: 'Ten Species Botanist',
    description: 'Collect 10 distinct species.',
    icon: 'auto_awesome',
  ),
  Achievement(
    id: 'legendary_find',
    title: 'Legendary Find',
    description: 'Record a Legendary rarity plant.',
    icon: 'star',
  ),
];
