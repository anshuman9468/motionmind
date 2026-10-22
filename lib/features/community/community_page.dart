import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/skill_badge.dart';
import '../providers/app_providers.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Text('Create Community Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassTextField(
                  hintText: 'Post Title / Topic',
                  controller: titleController,
                  prefixIcon: Icons.title_rounded,
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  hintText: 'Share technical insights or questions...',
                  controller: contentController,
                  prefixIcon: Icons.notes_rounded,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            GradientButton(
              text: 'Publish Post',
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post published to SkillVerse Community!'), backgroundColor: AppColors.emeraldGreen),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'SkillVerse Community',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Collaborate with senior engineers & AI researchers',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Posts List
              Expanded(
                child: ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(post.authorAvatar),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(post.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(post.authorRole, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                SkillBadge(label: post.tag, color: AppColors.cyanGlow),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Post Title & Content
                            Text(
                              post.title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              post.content,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 16),

                            // Actions Bar (Upvote, Comment, Share)
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => ref.read(communityPostsProvider.notifier).toggleLike(post.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: post.isLiked ? AppColors.primaryBlue.withValues(alpha: 0.2) : AppColors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: post.isLiked ? AppColors.cyanGlow : AppColors.glassBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          post.isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                                          color: post.isLiked ? AppColors.cyanGlow : AppColors.textMuted,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${post.upvotes}',
                                          style: TextStyle(
                                            color: post.isLiked ? AppColors.cyanGlow : AppColors.textMuted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.mode_comment_outlined, color: AppColors.textMuted, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${post.commentsCount} comments', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                                const Spacer(),
                                Text(post.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 100).ms),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
