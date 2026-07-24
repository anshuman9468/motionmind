class SkillModel {
  final String id;
  final String title;
  final String category;
  final String level;
  final double rating;
  final int learnersCount;
  final String duration;
  final String instructor;
  final String description;
  final String imageUrl;
  final List<String> keyTakeaways;
  final bool isEnrolled;
  final double progress;

  const SkillModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.rating,
    required this.learnersCount,
    required this.duration,
    required this.instructor,
    required this.description,
    required this.imageUrl,
    required this.keyTakeaways,
    this.isEnrolled = false,
    this.progress = 0.0,
  });

  SkillModel copyWith({
    bool? isEnrolled,
    double? progress,
  }) {
    return SkillModel(
      id: id,
      title: title,
      category: category,
      level: level,
      rating: rating,
      learnersCount: learnersCount,
      duration: duration,
      instructor: instructor,
      description: description,
      imageUrl: imageUrl,
      keyTakeaways: keyTakeaways,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      progress: progress ?? this.progress,
    );
  }
}
