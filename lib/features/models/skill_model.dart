class SkillModel {
  final String id;
  final String title;
  final String category;
  final String level; // Novice, Intermediate, Master
  final double rating; // General rating
  final double aiRating; // AI specific evaluation rating
  final double communityRating; // Peers rating
  final int learnersCount;
  final String duration;
  final String instructor;
  final String description;
  final String imageUrl;
  final List<String> keyTakeaways;
  final bool isEnrolled;
  final double progress;
  final String popularity; // Hot, Trending, Legendary
  final int coachesAvailable;
  final double professionalSimilarity; // Percentage match (e.g. 0.94)
  final bool isBookmarked;

  const SkillModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.rating,
    required this.aiRating,
    required this.communityRating,
    required this.learnersCount,
    required this.duration,
    required this.instructor,
    required this.description,
    required this.imageUrl,
    required this.keyTakeaways,
    required this.popularity,
    required this.coachesAvailable,
    required this.professionalSimilarity,
    this.isEnrolled = false,
    this.progress = 0.0,
    this.isBookmarked = false,
  });

  SkillModel copyWith({
    bool? isEnrolled,
    double? progress,
    bool? isBookmarked,
  }) {
    return SkillModel(
      id: id,
      title: title,
      category: category,
      level: level,
      rating: rating,
      aiRating: aiRating,
      communityRating: communityRating,
      learnersCount: learnersCount,
      duration: duration,
      instructor: instructor,
      description: description,
      imageUrl: imageUrl,
      keyTakeaways: keyTakeaways,
      popularity: popularity,
      coachesAvailable: coachesAvailable,
      professionalSimilarity: professionalSimilarity,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      progress: progress ?? this.progress,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
