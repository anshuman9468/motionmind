import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../models/user_model.dart';
import '../models/skill_model.dart';
import '../models/chat_message.dart';
import '../models/community_post.dart';
import '../models/achievement_model.dart';

// Firebase Services Providers with Auto-Fallback Detection
final authServiceProvider = Provider<AuthService>((ref) {
  try {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseAuthService();
    }
  } catch (_) {}
  return MockAuthService();
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  try {
    if (Firebase.apps.isNotEmpty) {
      return FirestoreService();
    }
  } catch (_) {}
  return MockDatabaseService();
});

// Onboarding Details State Provider
final onboardingDetailsProvider = StateProvider<Map<String, dynamic>>((ref) => {
      'name': 'Alex Vance',
      'age': 25,
      'gender': 'Male',
      'height': 175.0,
      'weight': 70.0,
      'dominantHand': 'Right',
      'learningGoal': 'Gold Wreath Olympian',
      'preferredSkills': ['Olympic Lifting', 'Core Kinematics'],
      'availableEquipment': ['Olympic Barbell', 'Postural Sensor Grid'],
      'experienceLevel': 'Intermediate',
      'practiceFrequency': 'Daily',
    });

// User State Provider
final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier()
      : super(const UserModel(
          id: 'usr_99',
          name: 'Alex Vance',
          email: 'alex.vance@skillverse.ai',
          avatarUrl: 'https://i.pravatar.cc/300?img=11',
          title: 'Senior AI Systems Architect',
          level: 42,
          xp: 18450,
          nextLevelXp: 20000,
          streakDays: 14,
          totalSkillsMastered: 18,
          globalRankPercentile: 99.4,
        ));

  void updateName(String newName) {
    state = UserModel(
      id: state.id,
      name: newName,
      email: state.email,
      avatarUrl: state.avatarUrl,
      title: state.title,
      level: state.level,
      xp: state.xp,
      nextLevelXp: state.nextLevelXp,
      streakDays: state.streakDays,
      totalSkillsMastered: state.totalSkillsMastered,
      globalRankPercentile: state.globalRankPercentile,
    );
  }

  void updateFromOnboarding(Map<String, dynamic> data) {
    state = UserModel(
      id: state.id,
      name: data['name'] ?? state.name,
      email: state.email,
      avatarUrl: state.avatarUrl,
      title: data['learningGoal'] ?? state.title,
      level: state.level,
      xp: state.xp,
      nextLevelXp: state.nextLevelXp,
      streakDays: state.streakDays,
      totalSkillsMastered: state.totalSkillsMastered,
      globalRankPercentile: state.globalRankPercentile,
    );
  }
}

// Category Filter Provider
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

// Skills Catalog Provider
final skillsProvider = StateNotifierProvider<SkillsNotifier, List<SkillModel>>((ref) {
  return SkillsNotifier();
});

class SkillsNotifier extends StateNotifier<List<SkillModel>> {
  SkillsNotifier()
      : super([
          const SkillModel(
            id: 'sk_1',
            title: 'Zeus Bolt: High-Output Basketball Telemetry',
            category: 'Sports',
            level: 'Master',
            rating: 4.95,
            aiRating: 4.98,
            communityRating: 4.92,
            learnersCount: 18500,
            duration: '14h 30m',
            instructor: 'Zeus (Thunder God)',
            description: 'Achieve god-like vertical leap, court vision, and shot mechanical telemetry precision.',
            imageUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc',
            keyTakeaways: [
              'Biomechanical jump telemetry calibration',
              'Optimal trajectory physics training',
              'No-look court spatial modeling'
            ],
            popularity: 'Legendary',
            coachesAvailable: 4,
            professionalSimilarity: 0.96,
            isEnrolled: true,
            progress: 0.65,
          ),
          const SkillModel(
            id: 'sk_2',
            title: 'Hermes Wings: Elite Badminton Footwork',
            category: 'Sports',
            level: 'Intermediate',
            rating: 4.88,
            aiRating: 4.90,
            communityRating: 4.86,
            learnersCount: 9400,
            duration: '8h 15m',
            instructor: 'Hermes (Winged Messenger)',
            description: 'Master fast shuttle interception, high-velocity lunges, and wrist snap acceleration.',
            imageUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea',
            keyTakeaways: [
              'Agility lateral acceleration vectors',
              'Shuttlecock vector calculations',
              'Fast court reposition dynamics'
            ],
            popularity: 'Trending',
            coachesAvailable: 3,
            professionalSimilarity: 0.88,
            isBookmarked: true,
          ),
          const SkillModel(
            id: 'sk_3',
            title: 'Ares Arena: High-Impact Boxing & Combat',
            category: 'Martial Arts',
            level: 'Master',
            rating: 4.97,
            aiRating: 4.99,
            communityRating: 4.95,
            learnersCount: 22000,
            duration: '18h 45m',
            instructor: 'Ares (God of War)',
            description: 'Master raw punching power metrics, stance stability, and split-second counter-attacks.',
            imageUrl: 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed',
            keyTakeaways: [
              'Kinetics kinetic chain mapping',
              'Reactive slip-defense telemetry',
              'Peak impact force optimization'
            ],
            popularity: 'Legendary',
            coachesAvailable: 6,
            professionalSimilarity: 0.98,
            isEnrolled: true,
            progress: 0.20,
          ),
          const SkillModel(
            id: 'sk_4',
            title: 'Hephaestus Strength: Olympic Powerlifting',
            category: 'Gym',
            level: 'Master',
            rating: 4.96,
            aiRating: 4.98,
            communityRating: 4.94,
            learnersCount: 15400,
            duration: '22h 10m',
            instructor: 'Hephaestus (Forge God)',
            description: 'Align lift kinematics, optimize squat depth telemetry, and master deadlift postures.',
            imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd',
            keyTakeaways: [
              'Barbell trajectory path analysis',
              'Lumbar angle pressure modeling',
              'Explosive force torque vectoring'
            ],
            popularity: 'Hot',
            coachesAvailable: 5,
            professionalSimilarity: 0.95,
            isEnrolled: true,
            progress: 0.45,
          ),
          const SkillModel(
            id: 'sk_5',
            title: 'Apollo Lyre: Classical Guitar Mastery',
            category: 'Music',
            level: 'Intermediate',
            rating: 4.91,
            aiRating: 4.94,
            communityRating: 4.88,
            learnersCount: 7800,
            duration: '11h 20m',
            instructor: 'Apollo (God of Music)',
            description: 'Align finger dexterity coordinates, sync advanced pitch harmonics, and learn classical rhythm.',
            imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1',
            keyTakeaways: [
              'Finger position biomechanics tracking',
              'Advanced acoustic resonance tuning',
              'Sight-reading classical compositions'
            ],
            popularity: 'Trending',
            coachesAvailable: 2,
            professionalSimilarity: 0.76,
          ),
          const SkillModel(
            id: 'sk_6',
            title: 'Hestia Flow: Meditative Breath & Vinyasa Yoga',
            category: 'Yoga',
            level: 'Novice',
            rating: 4.85,
            aiRating: 4.87,
            communityRating: 4.83,
            learnersCount: 6500,
            duration: '6h 30m',
            instructor: 'Hestia (Hearth Goddess)',
            description: 'Align postural core stability, heart-rate tracking, and breathing rhythms.',
            imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
            keyTakeaways: [
              'Vagal tone heart variability control',
              'Spine alignment biomechanics',
              'Pranayama oxygenation telemetry'
            ],
            popularity: 'Hot',
            coachesAvailable: 3,
            professionalSimilarity: 0.91,
          ),
          const SkillModel(
            id: 'sk_7',
            title: 'Terpsichore Rhythm: Modern Spatial Dance',
            category: 'Dance',
            level: 'Intermediate',
            rating: 4.90,
            aiRating: 4.92,
            communityRating: 4.88,
            learnersCount: 11000,
            duration: '9h 50m',
            instructor: 'Terpsichore (Muse of Dance)',
            description: 'Synthesize tempo tracking, visual stage presence, and full body gesture flows.',
            imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad',
            keyTakeaways: [
              'Center-of-gravity balance vectors',
              'Spatial mapping coordinates',
              'Rhythm sync micro-gestures'
            ],
            popularity: 'Trending',
            coachesAvailable: 4,
            professionalSimilarity: 0.84,
          ),
          const SkillModel(
            id: 'sk_8',
            title: 'Demeter Harvest: Michelin Culinary Telemetry',
            category: 'Cooking',
            level: 'Novice',
            rating: 4.89,
            aiRating: 4.91,
            communityRating: 4.87,
            learnersCount: 12200,
            duration: '10h 15m',
            instructor: 'Demeter (Harvest Goddess)',
            description: 'Master heat control kinetics, flavor profile chemistry, and presentation design.',
            imageUrl: 'https://images.unsplash.com/photo-1556910103-1c02745aae4d',
            keyTakeaways: [
              'Thermal profile kitchen safety',
              'Molecular gastronomy science',
              'Knife alignment kinematics'
            ],
            popularity: 'Hot',
            coachesAvailable: 3,
            professionalSimilarity: 0.72,
          ),
          const SkillModel(
            id: 'sk_9',
            title: 'Athena Art: Volumetric Painting & Sketching',
            category: 'Painting',
            level: 'Intermediate',
            rating: 4.94,
            aiRating: 4.96,
            communityRating: 4.92,
            learnersCount: 8800,
            duration: '12h 40m',
            instructor: 'Athena (Goddess of Wisdom)',
            description: 'Calibrate light values, depth shaders, and canvas composition ratios.',
            imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119',
            keyTakeaways: [
              'Chiaroscuro light shadow vectors',
              'Perspective distance modeling',
              'Pigment mix chemistry'
            ],
            popularity: 'Trending',
            coachesAvailable: 2,
            professionalSimilarity: 0.93,
          ),
          const SkillModel(
            id: 'sk_10',
            title: 'Helios Aperture: High-Exposure Photography',
            category: 'Photography',
            level: 'Novice',
            rating: 4.86,
            aiRating: 4.88,
            communityRating: 4.84,
            learnersCount: 7100,
            duration: '7h 20m',
            instructor: 'Helios (Sun God)',
            description: 'Capture dynamic light levels, exposure ratios, and manual focus precision.',
            imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32',
            keyTakeaways: [
              'Dynamic range exposure mappings',
              'Focal length distance grids',
              'Sunlight refraction photography'
            ],
            popularity: 'Hot',
            coachesAvailable: 2,
            professionalSimilarity: 0.81,
          ),
        ]);

  void toggleEnrollment(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            isEnrolled: !item.isEnrolled,
            progress: item.isEnrolled ? 0.0 : 0.1,
          )
        else
          item,
    ];
  }

  void toggleBookmark(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(isBookmarked: !item.isBookmarked)
        else
          item,
    ];
  }
}

// AI Coach Chat Provider
final aiCoachChatProvider = StateNotifierProvider<AiCoachChatNotifier, List<ChatMessage>>((ref) {
  return AiCoachChatNotifier();
});

class AiCoachChatNotifier extends StateNotifier<List<ChatMessage>> {
  AiCoachChatNotifier()
      : super([
          ChatMessage(
            id: 'm1',
            sender: 'ai',
            content: 'Greetings, Hero! I am Hercules AI, your divine mentor & digital twin guide. Based on your active telemetry, you are progressing toward the strength of the Gods. What trial shall we conquer today?',
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            suggestedActions: [
              'Simulate LLM Quantization Quiz',
              'Analyze My Digital Twin Gap',
              'Generate Code Review Challenge'
            ],
          ),
        ]);

  void sendMessage(String text) {
    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      sender: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    state = [...state, userMsg];

    Future.delayed(const Duration(milliseconds: 1200), () {
      final aiReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        sender: 'ai',
        content: 'Analyzing request: "$text"...\n\nYour Digital Twin model indicates strong proficiency in System Architecture. I recommend attempting the **LLM Quantization Practice Simulator** to boost your execution speed index by +4.2 points!',
        timestamp: DateTime.now(),
        suggestedActions: [
          'Launch Practice Simulator',
          'View Skill Radar Matrix',
          'Ask another question'
        ],
      );
      state = [...state, aiReply];
    });
  }
}

// Digital Twin Radar Metrics Provider
final digitalTwinMetricsProvider = StateProvider<Map<String, double>>((ref) => {
      'AI & LLMs': 0.92,
      'Architecture': 0.88,
      'Problem Solving': 0.95,
      'Leadership': 0.78,
      'Code Quality': 0.91,
      'Speed': 0.84,
    });

// Community Posts Provider
final communityPostsProvider = StateNotifierProvider<CommunityNotifier, List<CommunityPost>>((ref) {
  return CommunityNotifier();
});

class CommunityNotifier extends StateNotifier<List<CommunityPost>> {
  CommunityNotifier()
      : super([
          const CommunityPost(
            id: 'cp_1',
            authorName: 'Sarah Jenkins',
            authorAvatar: 'https://i.pravatar.cc/150?img=32',
            authorRole: 'Lead Machine Learning Engineer',
            title: 'Optimizing Llama-3 70B inference latency under 15ms with vLLM & Speculative Decoding',
            content: 'Hey SkillVerse community! We just deployed speculative decoding with a 1B draft model alongside Llama-3 70B on 4x H100s. The token latency dropped from 38ms to 12ms per token! Here is the config setup...',
            tag: 'AI & ML',
            upvotes: 342,
            commentsCount: 48,
            timeAgo: '2h ago',
            isLiked: false,
          ),
          const CommunityPost(
            id: 'cp_2',
            authorName: 'Dmitri Petrov',
            authorAvatar: 'https://i.pravatar.cc/150?img=60',
            authorRole: 'Staff Distributed Systems Dev',
            title: 'Why we replaced gRPC with Rust QUIC protocol for inter-cluster AI sync',
            content: 'High packet loss in cross-region clusters was choking our model weight synchronization. Switching to HTTP/3 QUIC streams reduced model load times by 40%...',
            tag: 'System Arch',
            upvotes: 219,
            commentsCount: 31,
            timeAgo: '5h ago',
            isLiked: true,
          ),
          const CommunityPost(
            id: 'cp_3',
            authorName: 'Elena Rostova',
            authorAvatar: 'https://i.pravatar.cc/150?img=47',
            authorRole: 'AI Venture Capital Director',
            title: 'Key traits of 10x AI Founders in 2026: Speed over Perfection',
            content: 'We reviewed 120 AI pitches this quarter. The founders who win are those leveraging digital twin simulators to train their teams 5x faster than traditional onboarding...',
            tag: 'Leadership',
            upvotes: 512,
            commentsCount: 94,
            timeAgo: '1d ago',
            isLiked: false,
          ),
        ]);

  void toggleLike(String id) {
    state = [
      for (final post in state)
        if (post.id == id)
          post.copyWith(
            isLiked: !post.isLiked,
            upvotes: post.isLiked ? post.upvotes - 1 : post.upvotes + 1,
          )
        else
          post,
    ];
  }
}

// Achievements Provider
final achievementsProvider = Provider<List<AchievementModel>>((ref) {
  return const [
    AchievementModel(
      id: 'ac_1',
      title: 'Neural Pioneer',
      description: 'Master 10 AI & Large Language Model skills',
      icon: Icons.psychology_rounded,
      color: AppColors.cyanGlow,
      progress: 1.0,
      isUnlocked: true,
      points: 500,
    ),
    AchievementModel(
      id: 'ac_2',
      title: 'System Titan',
      description: 'Achieve 90%+ score in Distributed Systems Practice Simulator',
      icon: Icons.hub_rounded,
      color: AppColors.primaryPurple,
      progress: 0.85,
      isUnlocked: false,
      points: 750,
    ),
    AchievementModel(
      id: 'ac_3',
      title: 'Unstoppable Streak',
      description: 'Maintain a 14-day learning streak in SkillVerse',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber,
      progress: 1.0,
      isUnlocked: true,
      points: 300,
    ),
    AchievementModel(
      id: 'ac_4',
      title: 'Global Top 1%',
      description: 'Reach top 1% percentile on the global leaderboard',
      icon: Icons.workspace_premium_rounded,
      color: AppColors.emeraldGreen,
      progress: 0.94,
      isUnlocked: false,
      points: 1500,
    ),
  ];
});
