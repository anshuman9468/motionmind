import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/skill_badge.dart';
import '../../core/widgets/section_header.dart';
import '../providers/app_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: GlassTextField(
            hintText: 'Display Name',
            controller: nameController,
            prefixIcon: Icons.person_outline_rounded,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            GradientButton(
              text: 'Save Changes',
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref.read(userProvider.notifier).updateName(nameController.text);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // User Card Header
              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyanGlow.withValues(alpha: 0.4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundImage: NetworkImage(user.avatarUrl),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.title,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SkillBadge(label: 'LVL 42', color: AppColors.cyanGlow),
                        const SizedBox(width: 8),
                        SkillBadge(label: user.email, color: AppColors.primaryPurple),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _UserStatItem(label: 'Skills', value: '${user.totalSkillsMastered}'),
                        const ContainerDivider(),
                        _UserStatItem(label: 'Streak', value: '${user.streakDays}d'),
                        const ContainerDivider(),
                        _UserStatItem(label: 'Global Rank', value: 'Top 0.6%'),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 24),

              // Action Options List
              GlassContainer(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.edit_rounded,
                      title: 'Edit Profile Information',
                      onTap: () => _showEditProfileDialog(context, ref, user.name),
                    ),
                    _ProfileTile(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Achievements & Badges Showcase',
                      onTap: () => context.push('/achievements'),
                    ),
                    _ProfileTile(
                      icon: Icons.settings_rounded,
                      title: 'Settings & Telemetry Preferences',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Verified Certificates Section
              SectionHeader(
                title: 'Verified Credentials',
                subtitle: 'On-chain verifiable skill proofs',
              ),
              const SizedBox(height: 12),

              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.emeraldGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LLM Fine-Tuning & Quantization', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Issued by SkillVerse AI Protocol • July 2026', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, color: AppColors.cyanGlow, size: 18),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              GradientButton(
                width: double.infinity,
                text: 'Sign Out of SkillVerse',
                gradient: const LinearGradient(colors: [AppColors.roseError, Colors.redAccent]),
                icon: Icons.logout_rounded,
                onPressed: () => context.go('/auth'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContainerDivider extends StatelessWidget {
  const ContainerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 30, width: 1, color: AppColors.glassBorder);
  }
}

class _UserStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _UserStatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyanGlow, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      onTap: onTap,
    );
  }
}
