class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String title;
  final int level;
  final int xp;
  final int nextLevelXp;
  final int streakDays;
  final int totalSkillsMastered;
  final double globalRankPercentile;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.title,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
    required this.streakDays,
    required this.totalSkillsMastered,
    required this.globalRankPercentile,
  });
}
