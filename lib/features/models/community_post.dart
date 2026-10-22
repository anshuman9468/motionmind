class CommunityPost {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String authorRole;
  final String title;
  final String content;
  final String tag;
  final int upvotes;
  final int commentsCount;
  final String timeAgo;
  final bool isLiked;

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.authorRole,
    required this.title,
    required this.content,
    required this.tag,
    required this.upvotes,
    required this.commentsCount,
    required this.timeAgo,
    this.isLiked = false,
  });

  CommunityPost copyWith({
    int? upvotes,
    bool? isLiked,
  }) {
    return CommunityPost(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorRole: authorRole,
      title: title,
      content: content,
      tag: tag,
      upvotes: upvotes ?? this.upvotes,
      commentsCount: commentsCount,
      timeAgo: timeAgo,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
