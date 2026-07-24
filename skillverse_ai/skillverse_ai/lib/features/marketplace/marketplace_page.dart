import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/skill_badge.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../models/skill_model.dart';
import '../providers/app_providers.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String _searchQuery = '';

  void _showSkillDetails(SkillModel skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GlassContainer(
          borderRadius: 28,
          backgroundColor: AppColors.surface,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkillBadge(label: skill.category, color: AppColors.cyanGlow),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                skill.title,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text('${skill.rating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  const Icon(Icons.people_outline_rounded, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 4),
                  Text('${skill.learnersCount} learners', style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 12),
                  const Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 4),
                  Text(skill.duration, style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                skill.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Text(
                'Key Competencies You Will Master:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              ...skill.keyTakeaways.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, _) {
                  final currentSkills = ref.watch(skillsProvider);
                  final currentItem = currentSkills.firstWhere((s) => s.id == skill.id);
                  return GradientButton(
                    width: double.infinity,
                    text: currentItem.isEnrolled ? 'Enrolled (Open Practice)' : 'Enroll in Track',
                    icon: currentItem.isEnrolled ? Icons.check_rounded : Icons.rocket_launch_rounded,
                    gradient: currentItem.isEnrolled ? AppColors.emeraldCyanGradient : AppColors.primaryGradient,
                    onPressed: () {
                      ref.read(skillsProvider.notifier).toggleEnrollment(skill.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(skillsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    final filteredSkills = skills.where((item) {
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final categories = ['All', 'AI & ML', 'System Arch', 'UI/UX', 'Leadership'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Skill Marketplace',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore high-impact AI & Engineering skill matrices',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Search Bar
              GlassTextField(
                hintText: 'Search skills, topics, fine-tuning...',
                prefixIcon: Icons.search_rounded,
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 16),

              // Categories Horizontal List
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textMuted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.cyanGlow : AppColors.glassBorder,
                        ),
                        onSelected: (val) {
                          ref.read(selectedCategoryProvider.notifier).state = cat;
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Skills List or Empty State
              Expanded(
                child: filteredSkills.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Matching Skill Track',
                        description: 'Try adjusting your search filters or browse all categories.',
                        icon: Icons.search_off_rounded,
                      )
                    : ListView.builder(
                        itemCount: filteredSkills.length,
                        itemBuilder: (context, index) {
                          final item = filteredSkills[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassContainer(
                              onTap: () => _showSkillDetails(item),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Hero(
                                    tag: 'skill_${item.id}',
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        image: DecorationImage(
                                          image: NetworkImage(item.imageUrl),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            SkillBadge(label: item.category, color: AppColors.cyanGlow),
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${item.rating}',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Instructor: ${item.instructor}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text(
                                              item.duration,
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                            ),
                                            const Spacer(),
                                            if (item.isEnrolled)
                                              const SkillBadge(label: 'Enrolled', color: AppColors.emeraldGreen)
                                            else
                                              const Text('Tap to details →', style: TextStyle(color: AppColors.cyanGlow, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: (index * 80).ms),
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
