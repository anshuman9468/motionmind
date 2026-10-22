import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/skill_badge.dart';
import '../../core/widgets/digital_twin_radar.dart';
import '../providers/app_providers.dart';
import '../models/user_model.dart';
import '../models/achievement_model.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final onboarding = ref.watch(onboardingDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Dashboard Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Atlas Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI Twin Telemetry & Bio-Metrics Matrix',
                            style: TextStyle(
                              color: AppColors.cyanGlow.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      // Drachma (Coins) Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.toll_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '1,240 d',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primaryBlue,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.cyanGlow,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Competency Matrix'),
                Tab(text: 'Practice & Bio'),
                Tab(text: 'AI Insights'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(user),
                  _buildCompetencyTab(),
                  _buildPracticeBioTab(onboarding),
                  _buildAiInsightsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: OVERVIEW ---
  Widget _buildOverviewTab(UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's Goal Section
          SectionHeader(
            title: "Today's Telemetry Goal",
            subtitle: "XP target & task validation checklist",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            hasGlow: true,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Animated Progress Ring
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 0.75),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (rect) {
                              return AppColors.primaryGradient.createShader(rect);
                            },
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(value * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ).animate().scale(duration: 400.ms),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '150 / 200 XP earned today',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      _buildDailyCheckItem("Complete 1 practice room", true),
                      _buildDailyCheckItem("Read AI coach recommendation", true),
                      _buildDailyCheckItem("Calibrate dynamic postural balance", false),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Grid (XP, Level, Streak, Learning Speed)
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Learning Velocity',
                  value: '1.4x Speed',
                  trend: 'Vanguard',
                  isPositive: true,
                  icon: Icons.speed_rounded,
                  iconColor: AppColors.cyanGlow,
                ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(begin: 0.1, end: 0.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'XP Accumulated',
                  value: '${user.xp} XP',
                  trend: '+520 today',
                  isPositive: true,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.primaryBlue,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1, end: 0.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Current Level',
                  value: 'LVL ${user.level}',
                  trend: 'Top 0.6% rank',
                  isPositive: true,
                  icon: Icons.workspace_premium_rounded,
                  iconColor: AppColors.primaryPurple,
                ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.1, end: 0.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Active Streak',
                  value: '${user.streakDays} Days',
                  trend: 'Locked In',
                  isPositive: true,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.amber,
                ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.1, end: 0.0),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Weekly Progress
          SectionHeader(
            title: 'Weekly Velocity (Hours)',
            subtitle: 'Study time telemetry logs',
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 16),
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 6,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.surfaceLight,
                    tooltipBorder: const BorderSide(color: AppColors.glassBorder),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY} hrs',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
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
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == 2 || value == 4 || value == 6) {
                          return Text(
                            '${value.toInt()}h',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.glassBorder.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBar(0, 3.5, AppColors.cyanGlow),
                  _makeBar(1, 4.2, AppColors.primaryBlue),
                  _makeBar(2, 2.8, AppColors.cyanGlow),
                  _makeBar(3, 5.1, AppColors.primaryPurple),
                  _makeBar(4, 4.8, AppColors.emeraldGreen),
                  _makeBar(5, 1.5, AppColors.amberWarning),
                  _makeBar(6, 3.9, AppColors.primaryBlue),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 28),

          // Monthly Progress
          SectionHeader(
            title: 'Monthly Cumulative XP',
            subtitle: 'Learning curve slope and threshold progress',
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 16),
            height: 220,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => AppColors.surfaceLight,
                    tooltipBorder: const BorderSide(color: AppColors.glassBorder),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()} XP',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: AppColors.primaryBlue.withValues(alpha: 0.4),
                          strokeWidth: 2,
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 6,
                            color: AppColors.primaryBlue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.glassBorder.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        switch (val.toInt()) {
                          case 0:
                            return const Text('Jul 01', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                          case 6:
                            return const Text('Jul 07', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                          case 13:
                            return const Text('Jul 14', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                          case 20:
                            return const Text('Jul 21', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                          case 27:
                            return const Text('Jul 28', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == 10000 || value == 15000 || value == 20000) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 30,
                minY: 10000,
                maxY: 20000,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 10500),
                      FlSpot(5, 11200),
                      FlSpot(10, 12800),
                      FlSpot(15, 14000),
                      FlSpot(20, 16100),
                      FlSpot(25, 17500),
                      FlSpot(30, 18450),
                    ],
                    isCurved: true,
                    gradient: AppColors.primaryGradient,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withValues(alpha: 0.25),
                          AppColors.primaryPurple.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 700.ms),
        ],
      ),
    );
  }

  Widget _buildDailyCheckItem(String text, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? AppColors.emeraldGreen : AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: done ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
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
          width: 14,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 6,
            color: AppColors.surface,
          ),
        ),
      ],
    );
  }

  // --- TAB 2: COMPETENCY MATRIX & DIGITAL TWIN ---
  Widget _buildCompetencyTab() {
    final metrics = ref.watch(digitalTwinMetricsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill Radar Chart
          SectionHeader(
            title: "Skill Radar Chart",
            subtitle: "Competency dimensions vector mapping",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            hasGlow: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: DigitalTwinRadarChart(metrics: metrics, size: 270),
                ),
                const SizedBox(height: 20),
                // Legend
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: metrics.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(e.key, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(width: 6),
                          Text('${(e.value * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          // Digital Twin Overview Card
          SectionHeader(
            title: "Digital Twin Status",
            subtitle: "Mathematical twin model telemetry stream",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
            borderColor: AppColors.primaryPurple.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology_rounded, color: AppColors.cyanGlow, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Alex_Vance_Twin_v2.4',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: AppColors.emeraldGreen, shape: BoxShape.circle),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).custom(
                            duration: 1000.ms,
                            builder: (context, val, child) => Opacity(
                              opacity: 0.3 + (val * 0.7),
                              child: child,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('SYNCED', style: TextStyle(color: AppColors.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your cognitive & biomechanical simulation parameters are compiled. The model matches your motor response profile and speed metrics.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _SmallParameterText("Accuracy: 96.2%"),
                    _SmallParameterText("Drift Index: <0.02"),
                    _SmallParameterText("Latency: 14ms"),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // Professional Similarity
          SectionHeader(
            title: "Professional Similarity",
            subtitle: "Vector comparison against industry target models",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Principal AI Architect Target', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('94.8% Match', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 0.948),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Core Domain Gaps to Reach 100% Vector Fit:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildGapItem("Distributed Consensus Mechanisms", 0.82),
                _buildGapItem("Llama Speculative Quantization", 0.65),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 24),

          // Strengths & Weaknesses
          SectionHeader(
            title: "Strengths & Weaknesses",
            subtitle: "Top verified capabilities & telemetry growth opportunities",
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AppColors.emeraldGreen.withValues(alpha: 0.05),
                  borderColor: AppColors.emeraldGreen.withValues(alpha: 0.25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.add_task_rounded, color: AppColors.emeraldGreen, size: 16),
                          SizedBox(width: 6),
                          Text('Strengths', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBulletItem("QLoRA Tuning"),
                      _buildBulletItem("Postural Symmetry"),
                      _buildBulletItem("High-Concurrency"),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideX(begin: -0.1, end: 0.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AppColors.roseError.withValues(alpha: 0.05),
                  borderColor: AppColors.roseError.withValues(alpha: 0.25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.amberWarning, size: 16),
                          SizedBox(width: 6),
                          Text('Weaknesses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBulletItem("Model Quantization"),
                      _buildBulletItem("Explosive Squat Lift"),
                      _buildBulletItem("Vagal Tone Control"),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideX(begin: 0.1, end: 0.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGapItem(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(value * 100).toInt()}%', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  // --- TAB 3: PRACTICE HISTORY & SKILL DNA ---
  Widget _buildPracticeBioTab(Map<String, dynamic> onboarding) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Practice History (Timeline)
          SectionHeader(
            title: "Practice History",
            subtitle: "Completed simulation rooms & validation grades",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildTimelineItem(
                  time: "Today, 02:15 AM",
                  title: "QLoRA Inference Quantization Room",
                  grade: "A+",
                  points: "+50 XP",
                  icon: Icons.psychology_rounded,
                  color: AppColors.cyanGlow,
                ),
                _buildTimelineDivider(),
                _buildTimelineItem(
                  time: "Yesterday, 04:30 PM",
                  title: "Olympic Barbell Squat Kinematics",
                  grade: "A",
                  points: "+40 XP",
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.primaryBlue,
                ),
                _buildTimelineDivider(),
                _buildTimelineItem(
                  time: "2 days ago",
                  title: "Distributed Consensuses Validation",
                  grade: "B+",
                  points: "+30 XP",
                  icon: Icons.lan_rounded,
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          // Skill DNA Biometrics Holographic Scanner
          SectionHeader(
            title: "Skill DNA: Telemetry Scan",
            subtitle: "Interactive biomechanical model hot-spots",
          ),
          const SizedBox(height: 12),
          const HolographicTwinScanner().animate().fadeIn(duration: 600.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // Skill DNA - Body Metrics
          SectionHeader(
            title: "Skill DNA: Body Metrics",
            subtitle: "Physiological telemetry specifications",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMetricDetailBox("Height", "${onboarding['height'] ?? 175.0} cm", Icons.height_rounded),
                    const SizedBox(width: 10),
                    _buildMetricDetailBox("Weight", "${onboarding['weight'] ?? 70.0} kg", Icons.fitness_center_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMetricDetailBox("Dominant Hand", "${onboarding['dominantHand'] ?? 'Right'}", Icons.back_hand_rounded),
                    const SizedBox(width: 10),
                    _buildMetricDetailBox("Vagal Tone (HRV)", "68 ms", Icons.favorite_rounded),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String title,
    required String grade,
    required String points,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 3),
              Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SkillBadge(label: grade, color: AppColors.emeraldGreen),
            const SizedBox(height: 4),
            Text(points, style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      height: 16,
      width: 1.5,
      color: AppColors.glassBorder,
      alignment: Alignment.centerLeft,
    );
  }

  Widget _buildMetricDetailBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyanGlow, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 4: AI INSIGHTS & LESSONS ---
  Widget _buildAiInsightsTab() {
    final achievements = ref.watch(achievementsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Insights & Suggestions
          SectionHeader(
            title: "AI Insights & Suggestions",
            subtitle: "Real-time telemetry analysis alerts",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightItem(
                  icon: Icons.psychology_rounded,
                  color: AppColors.primaryBlue,
                  title: "Quantization Target Recommendation",
                  description: "Simulate **LLM Fine-Tuning** to narrow your 3.8% gap against the Senior Architect cohort profile.",
                  actionText: "Launch Simulator",
                  onAction: () => context.push('/practice'),
                ),
                const Divider(color: AppColors.glassBorder, height: 24),
                _buildInsightItem(
                  icon: Icons.balance_rounded,
                  color: AppColors.emeraldGreen,
                  title: "Postural Stability Vector Correction",
                  description: "Postural Sensor Grid indicates slight trunk lean during Olympic Squats. Focus on symmetry calibrations.",
                  actionText: "Open AI Coach",
                  onAction: () => context.push('/ai-coach'),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          // Upcoming Lessons Schedule
          SectionHeader(
            title: "Upcoming Scheduled Lessons",
            subtitle: "Mentor classes booked for your twin calibration",
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLessonScheduleRow(
                  time: "Today, 11:30 AM",
                  coach: "Ares (War God)",
                  topic: "Greek Pantheon Arena Combat Stances",
                  icon: Icons.sports_kabaddi_rounded,
                ),
                const Divider(color: AppColors.glassBorder, height: 20),
                _buildLessonScheduleRow(
                  time: "Tomorrow, 09:00 AM",
                  coach: "Demeter (Harvest Goddess)",
                  topic: "Michelin Culinary Molecular Chemistry",
                  icon: Icons.science_rounded,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // Achievements & Badges Grid
          SectionHeader(
            title: "Laurel & Shield Achievements",
            subtitle: "NFT-grade credential badges unlocked",
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final badge = achievements[index];
              return InkWell(
                onTap: () => _showBadgeDetails(context, badge),
                borderRadius: BorderRadius.circular(16),
                child: GlassContainer(
                  borderColor: badge.isUnlocked ? badge.color : AppColors.glassBorder,
                  backgroundColor: badge.isUnlocked ? badge.color.withValues(alpha: 0.05) : null,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: badge.isUnlocked ? badge.color.withValues(alpha: 0.15) : AppColors.surface,
                          border: Border.all(color: badge.isUnlocked ? badge.color : AppColors.glassBorder),
                        ),
                        child: Icon(badge.icon, color: badge.isUnlocked ? badge.color : AppColors.textMuted, size: 24),
                      ),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: badge.isUnlocked ? Colors.white : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                      ),
                      if (badge.isUnlocked)
                        SkillBadge(label: '+${badge.points} XP', color: badge.color)
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: badge.progress,
                            minHeight: 4,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, AchievementModel badge) {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              color: Colors.transparent,
              child: GlassContainer(
                hasGlow: badge.isUnlocked,
                borderColor: badge.isUnlocked ? badge.color : AppColors.glassBorder,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.isUnlocked ? badge.color.withValues(alpha: 0.15) : AppColors.surface,
                        border: Border.all(color: badge.isUnlocked ? badge.color : AppColors.glassBorder, width: 2),
                        boxShadow: badge.isUnlocked
                            ? [
                                BoxShadow(
                                  color: badge.color.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(badge.icon, color: badge.isUnlocked ? badge.color : AppColors.textMuted, size: 48),
                    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 18),
                    Text(
                      badge.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.isUnlocked ? 'UNLOCKED ACHIEVEMENT' : 'IN PROGRESS',
                      style: TextStyle(
                        color: badge.isUnlocked ? AppColors.emeraldGreen : AppColors.amberWarning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      badge.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (badge.isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: badge.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: badge.color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '+${badge.points} XP Reward Claimed',
                          style: TextStyle(color: badge.color, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: badge.progress,
                          minHeight: 8,
                          backgroundColor: AppColors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${(badge.progress * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Text(
                          'Close Uplink',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      children: _parseBoldMarkdown(description),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (actionText != null && onAction != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, color: color, size: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _parseBoldMarkdown(String text) {
    final spans = <InlineSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(text: parts[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return spans;
  }

  Widget _buildLessonScheduleRow({
    required String time,
    required String coach,
    required String topic,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 3),
              Text('Coach: $coach', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassBorderGlow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time,
            style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold, fontSize: 9),
          ),
        ),
      ],
    );
  }
}

class _SmallParameterText extends StatelessWidget {
  final String text;
  const _SmallParameterText(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 2.5, backgroundColor: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class HolographicTwinScanner extends StatefulWidget {
  const HolographicTwinScanner({super.key});

  @override
  State<HolographicTwinScanner> createState() => _HolographicTwinScannerState();
}

class _HolographicTwinScannerState extends State<HolographicTwinScanner> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  String _selectedHotspot = 'Head';

  final Map<String, Map<String, String>> _hotspotDetails = {
    'Head': {
      'title': 'Vagal Tone (HRV)',
      'value': '68 ms',
      'desc': 'Measures autonomic neural synchronization. Your parasympathetic response indicates high resilience & fast cardiovascular calibration.',
    },
    'Torso': {
      'title': 'Postural Precision Index',
      'value': '94.2%',
      'desc': 'Trunk alignment relative to gravity vector. Indicates excellent spinal stabilization with negligible shear torque.',
    },
    'Pelvis': {
      'title': 'Center of Gravity Deviation',
      'value': '3.2%',
      'desc': 'Dynamic balance sway deviation during load transition. Minimal drift measured across sagittal planes.',
    },
    'Feet': {
      'title': 'Stance Weight Symmetry',
      'value': '51% L / 49% R',
      'desc': 'Ground reaction force distribution. Bilateral limb balance is close to absolute parity (ideal torque distribution).',
    },
  };

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Widget _buildHotspotDot(String key, double top, double left) {
    final isSelected = _selectedHotspot == key;
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedHotspot = key;
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isSelected ? AppColors.primaryBlue : AppColors.cyanGlow).withValues(alpha: 0.15),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryBlue : AppColors.cyanGlow,
                    width: 1,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 800.ms,
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.3, 1.3),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primaryBlue : AppColors.cyanGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _hotspotDetails[_selectedHotspot]!;

    return Column(
      children: [
        GlassContainer(
          height: 340,
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: HolographicScannerPainter(
                        scanProgress: _scanController.value,
                      ),
                    );
                  },
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final midX = constraints.maxWidth / 2;
                  return Stack(
                    children: [
                      _buildHotspotDot('Head', 50 - 11, midX - 11),
                      _buildHotspotDot('Torso', 120 - 11, midX - 11),
                      _buildHotspotDot('Pelvis', 190 - 11, midX - 11),
                      _buildHotspotDot('Feet', 290 - 11, midX - 11),
                    ],
                  );
                },
              ),
              Positioned(
                top: 15,
                left: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYSTEM: ACTIVE_SCAN',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SELECTED NODE: ${_selectedHotspot.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderColor: AppColors.primaryBlue.withValues(alpha: 0.25),
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _selectedHotspot == 'Head'
                        ? Icons.favorite_rounded
                        : _selectedHotspot == 'Torso'
                            ? Icons.accessibility_new_rounded
                            : _selectedHotspot == 'Pelvis'
                                ? Icons.gps_fixed_rounded
                                : Icons.height_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    details['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      details['value']!,
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                details['desc']!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HolographicScannerPainter extends CustomPainter {
  final double scanProgress;

  HolographicScannerPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final gridPaint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 20) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    final bodyPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final glowPaint = Paint()
      ..color = AppColors.cyanGlow.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(width / 2, 50), 16, bodyPaint);
    canvas.drawCircle(Offset(width / 2, 50), 16, glowPaint);

    canvas.drawLine(Offset(width / 2, 66), Offset(width / 2, 190), bodyPaint);
    canvas.drawLine(Offset(width / 2 - 35, 80), Offset(width / 2 + 35, 80), bodyPaint);

    canvas.drawLine(Offset(width / 2 - 35, 80), Offset(width / 2 - 45, 140), bodyPaint);
    canvas.drawLine(Offset(width / 2 - 45, 140), Offset(width / 2 - 40, 180), bodyPaint);
    canvas.drawLine(Offset(width / 2 + 35, 80), Offset(width / 2 + 45, 140), bodyPaint);
    canvas.drawLine(Offset(width / 2 + 45, 140), Offset(width / 2 + 40, 180), bodyPaint);

    canvas.drawLine(Offset(width / 2 - 20, 190), Offset(width / 2 + 20, 190), bodyPaint);

    canvas.drawLine(Offset(width / 2 - 20, 190), Offset(width / 2 - 25, 250), bodyPaint);
    canvas.drawLine(Offset(width / 2 - 25, 250), Offset(width / 2 - 20, 300), bodyPaint);
    canvas.drawLine(Offset(width / 2 + 20, 190), Offset(width / 2 + 25, 250), bodyPaint);
    canvas.drawLine(Offset(width / 2 + 25, 250), Offset(width / 2 + 20, 300), bodyPaint);

    final scanY = height * scanProgress;
    final laserPaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2.0;

    final laserGlowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryBlue.withValues(alpha: 0.0),
          AppColors.primaryBlue.withValues(alpha: 0.20),
          AppColors.primaryBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 15, width, 30));

    canvas.drawRect(Rect.fromLTWH(0, scanY - 15, width, 30), laserGlowPaint);
    canvas.drawLine(Offset(0, scanY), Offset(width, scanY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant HolographicScannerPainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress;
}
