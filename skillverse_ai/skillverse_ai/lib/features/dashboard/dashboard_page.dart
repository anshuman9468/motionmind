import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Analytics Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Telemetry overview & learning velocity insights',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // KPI Stats Row
              Row(
                children: const [
                  Expanded(
                    child: StatCard(
                      title: 'Hours Logged',
                      value: '142.5 h',
                      trend: '+12.4h this week',
                      isPositive: true,
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.cyanGlow,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: StatCard(
                      title: 'Simulations Score',
                      value: '96.2%',
                      trend: '+1.8%',
                      isPositive: true,
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.emeraldGreen,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Weekly Activity Bar Chart (FL Chart)
              SectionHeader(
                title: 'Weekly Velocity (Hours)',
                subtitle: 'Learning time spent per day',
              ),
              const SizedBox(height: 12),

              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(20),
                height: 260,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 6,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (val.toInt() >= 0 && val.toInt() < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[val.toInt()],
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeBar(0, 3.5, AppColors.cyanGlow),
                      _makeBar(1, 4.2, AppColors.primaryBlue),
                      _makeBar(2, 2.8, AppColors.cyanGlow),
                      _makeBar(3, 5.1, AppColors.primaryPurple),
                      _makeBar(4, 4.8, AppColors.emeraldGreen),
                      _makeBar(5, 1.5, AppColors.amberWarning),
                      _makeBar(6, 3.9, AppColors.cyanGlow),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms),
              ),

              const SizedBox(height: 28),

              // Skill Domain Mastery Breakdown
              SectionHeader(
                title: 'Skill Matrix Breakdown',
                subtitle: 'Mastery levels across core domains',
              ),
              const SizedBox(height: 12),

              _MasteryProgressItem(
                title: 'AI & Large Language Models',
                progress: 0.92,
                color: AppColors.cyanGlow,
              ),
              _MasteryProgressItem(
                title: 'High-Concurrency System Architecture',
                progress: 0.88,
                color: AppColors.primaryPurple,
              ),
              _MasteryProgressItem(
                title: 'Spatial UI & Neural Design',
                progress: 0.75,
                color: AppColors.emeraldGreen,
              ),
              _MasteryProgressItem(
                title: 'Billion-Dollar Founder Leadership',
                progress: 0.84,
                color: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static BarChartGroupData _makeBar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: BorderRadius.circular(6),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 6,
            color: AppColors.surface,
          ),
        ),
      ],
    );
  }
}

class _MasteryProgressItem extends StatelessWidget {
  final String title;
  final double progress;
  final Color color;

  const _MasteryProgressItem({
    required this.title,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
