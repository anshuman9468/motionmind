import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  int _selectedFilter = 0; // 0: Global, 1: Weekly

  final List<_LeaderboardUser> _rankings = const [
    _LeaderboardUser(rank: 1, name: 'Elena Rostova', xp: '28,450 XP', avatar: 'https://i.pravatar.cc/150?img=47', title: 'AI Venture Director'),
    _LeaderboardUser(rank: 2, name: 'Alex Vance', xp: '24,800 XP', avatar: 'https://i.pravatar.cc/150?img=11', title: 'Senior AI Architect (You)', isCurrentUser: true),
    _LeaderboardUser(rank: 3, name: 'Dmitri Petrov', xp: '22,150 XP', avatar: 'https://i.pravatar.cc/150?img=60', title: 'Staff Systems Dev'),
    _LeaderboardUser(rank: 4, name: 'Sarah Jenkins', xp: '19,900 XP', avatar: 'https://i.pravatar.cc/150?img=32', title: 'Lead ML Engineer'),
    _LeaderboardUser(rank: 5, name: 'Kenji Sato', xp: '18,400 XP', avatar: 'https://i.pravatar.cc/150?img=12', title: 'Robotics Specialist'),
    _LeaderboardUser(rank: 6, name: 'Maya Lin', xp: '17,200 XP', avatar: 'https://i.pravatar.cc/150?img=25', title: 'Quantum Researcher'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Leaderboard',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Top 1% skill builders',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _ToggleChip(
                          text: 'Global',
                          isSelected: _selectedFilter == 0,
                          onTap: () => setState(() => _selectedFilter = 0),
                        ),
                        _ToggleChip(
                          text: 'Weekly',
                          isSelected: _selectedFilter == 1,
                          onTap: () => setState(() => _selectedFilter = 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Top 3 Podium
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2nd Place
                  _PodiumCard(user: _rankings[1], height: 140, crownColor: Colors.grey.shade300),
                  const SizedBox(width: 12),
                  // 1st Place
                  _PodiumCard(user: _rankings[0], height: 170, crownColor: Colors.amber, isFirst: true),
                  const SizedBox(width: 12),
                  // 3rd Place
                  _PodiumCard(user: _rankings[2], height: 125, crownColor: Colors.brown.shade300),
                ],
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 28),

              // Remaining Rank List
              Expanded(
                child: ListView.builder(
                  itemCount: _rankings.length - 3,
                  itemBuilder: (context, index) {
                    final user = _rankings[index + 3];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassContainer(
                        borderColor: user.isCurrentUser ? AppColors.cyanGlow : AppColors.glassBorder,
                        backgroundColor: user.isCurrentUser ? AppColors.primaryBlue.withValues(alpha: 0.25) : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '#${user.rank}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(user.avatar),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(user.title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              user.xp,
                              style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
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

class _ToggleChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final _LeaderboardUser user;
  final double height;
  final Color crownColor;
  final bool isFirst;

  const _PodiumCard({
    required this.user,
    required this.height,
    required this.crownColor,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.workspace_premium_rounded, color: crownColor, size: isFirst ? 28 : 22),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: isFirst ? 28 : 22,
          backgroundImage: NetworkImage(user.avatar),
        ),
        const SizedBox(height: 6),
        GlassContainer(
          width: 95,
          height: height,
          padding: const EdgeInsets.all(8),
          borderColor: isFirst ? AppColors.cyanGlow : AppColors.glassBorder,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${user.rank}',
                style: TextStyle(color: crownColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                user.name.split(' ').first,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                user.xp,
                style: const TextStyle(color: AppColors.cyanGlow, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardUser {
  final int rank;
  final String name;
  final String xp;
  final String avatar;
  final String title;
  final bool isCurrentUser;

  const _LeaderboardUser({
    required this.rank,
    required this.name,
    required this.xp,
    required this.avatar,
    required this.title,
    this.isCurrentUser = false,
  });
}
