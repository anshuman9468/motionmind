import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../models/skill_model.dart';
import '../models/chat_message.dart';
import '../models/community_post.dart';
import '../models/achievement_model.dart';

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
            title: 'LLM Fine-Tuning & Quantization Masterclass',
            category: 'AI & ML',
            level: 'Advanced',
            rating: 4.9,
            learnersCount: 14200,
            duration: '12h 30m',
            instructor: 'Dr. Evelyn Reed',
            description: 'Master LoRA, QLoRA, vLLM, and TensorRT-LLM to deploy sub-billion parameter models in production at zero latency.',
            imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780efad99a',
            keyTakeaways: [
              'Fine-tune Llama-3 & Mistral with QLoRA',
              'Optimize inference memory using GGUF quantization',
              'Deploy high-throughput API endpoints with vLLM'
            ],
            isEnrolled: true,
            progress: 0.65,
          ),
          const SkillModel(
            id: 'sk_2',
            title: 'High-Concurrency Distributed Systems Architecture',
            category: 'System Arch',
            level: 'Expert',
            rating: 4.95,
            learnersCount: 9800,
            duration: '18h 45m',
            instructor: 'Marcus Vance',
            description: 'Design bulletproof event-driven microservices with Kafka, Redis Cluster, and gRPC handling millions of RPS.',
            imageUrl: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31',
            keyTakeaways: [
              'Event Sourcing & CQRS architecture patterns',
              'Distributed locks and consensus algorithms (Raft)',
              'Zero-downtime database sharding and scaling'
            ],
            isEnrolled: true,
            progress: 0.35,
          ),
          const SkillModel(
            id: 'sk_3',
            title: 'Neural Interface & Spatial UI Design',
            category: 'UI/UX',
            level: 'Intermediate',
            rating: 4.88,
            learnersCount: 7600,
            duration: '9h 15m',
            instructor: 'Sora Takahashi',
            description: 'Design immersive visionOS and Spatial UI glassmorphism interactions with 60fps micro-animations.',
            imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe',
            keyTakeaways: [
              'Volumetric UI design principles',
              'Depth hierarchy and translucent materials',
              'Eye-tracking and haptic gesture design'
            ],
            isEnrolled: false,
            progress: 0.0,
          ),
          const SkillModel(
            id: 'sk_4',
            title: 'Quantum Computing Algorithms & Qiskit',
            category: 'AI & ML',
            level: 'Advanced',
            rating: 4.92,
            learnersCount: 5400,
            duration: '14h 20m',
            instructor: 'Prof. David Chen',
            description: 'Implement Shor algorithm, Grover search, and VQE on IBM Quantum hardware via Python Qiskit SDK.',
            imageUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb',
            keyTakeaways: [
              'Qubit state vectors & Bloch Sphere math',
              'Quantum error correction & surface codes',
              'Quantum machine learning (QNNs)'
            ],
            isEnrolled: false,
            progress: 0.0,
          ),
          const SkillModel(
            id: 'sk_5',
            title: 'AI Founder & Billion-Dollar Executive Vision',
            category: 'Leadership',
            level: 'All Levels',
            rating: 4.98,
            learnersCount: 21500,
            duration: '8h 10m',
            instructor: 'Elena Rostova',
            description: 'Scale tech startups from seed to unicorn with strategic product positioning, AI velocity, and team leadership.',
            imageUrl: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c',
            keyTakeaways: [
              'Build defensible AI moats and network effects',
              'Structure high-output autonomous engineering units',
              'Master VC pitch decks & series A term sheets'
            ],
            isEnrolled: true,
            progress: 0.90,
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
            content: 'Hello Alex! I am your SkillVerse AI Twin & Coach. Based on your current telemetry, you are 85% ready for the Principal AI Architect assessment. What skill matrix shall we elevate today?',
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
