import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/preview_badge.dart';
import '../providers/app_providers.dart';

/// The first screen a new user sees. Real history is never fabricated; the
/// progress card is an explicitly labelled preview until sessions exist.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final firstName = user.name.trim().split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(
                    firstName: firstName,
                    onMenu: () => Scaffold.of(context).openDrawer(),
                    onSettings: () => context.push('/settings'),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to MotionMind',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your next great session starts here.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    width: double.infinity,
                    text: 'Start practice',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.push('/practice'),
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'Your progress',
                    subtitle: 'Your real session insights will appear here.',
                  ),
                  const SizedBox(height: 10),
                  const _ProgressPreviewCard(),
                  const SizedBox(height: 24),
                  const _SectionHeading(
                    title: 'Explore movement',
                    subtitle: 'Choose a sport or workout to get started.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ExploreCard(
                          icon: Icons.sports_basketball_rounded,
                          title: 'Sports',
                          subtitle: 'Technique and athletic movement',
                          onTap: () => context.go('/marketplace'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExploreCard(
                          icon: Icons.fitness_center_rounded,
                          title: 'Gym',
                          subtitle: 'Form, control, and repetitions',
                          onTap: () => context.push('/practice'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassContainer(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'MotionMind gives feedback only when your camera view and movement data are clear enough to assess.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.onMenu,
    required this.onSettings,
  });

  final String firstName;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          tooltip: 'Open menu',
        ),
        const SizedBox(width: 2),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: .22),
                blurRadius: 14,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            firstName.isEmpty ? 'M' : firstName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AppColors.textOnAccent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'MotionMind',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: .2,
            ),
          ),
        ),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProgressPreviewCard extends StatelessWidget {
  const _ProgressPreviewCard();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Example progress',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: PreviewBadge()),
          const SizedBox(height: 14),
          const Row(
            children: [
              _HomeMockMetric(value: '6', label: 'sessions'),
              _HomeMockMetric(value: '42m', label: 'training'),
              _HomeMockMetric(value: '38', label: 'reps'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Illustrative values only. Your dashboard will update after real practice sessions.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMockMetric extends StatelessWidget {
  const _HomeMockMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cyanGlow,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: AppColors.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
