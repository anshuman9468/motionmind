import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../providers/app_providers.dart';

class AiCoachPage extends ConsumerStatefulWidget {
  const AiCoachPage({super.key});

  @override
  ConsumerState<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends ConsumerState<AiCoachPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    ref.read(aiCoachChatProvider.notifier).sendMessage(text);
    _msgController.clear();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(aiCoachChatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with AI Avatar Telemetry
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.cyanPurpleGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanGlow.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.psychology_rounded, color: AppColors.cyanGlow, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SkillVerse AI Mentor',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Row(
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: AppColors.emeraldGreen),
                            SizedBox(width: 6),
                            Text(
                              'Telemetry Active • LLM-3 70B Engine',
                              style: TextStyle(color: AppColors.emeraldGreen, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Audio Wave Graphic
                    Row(
                      children: List.generate(
                        4,
                        (index) => Container(
                          width: 3,
                          height: 12.0 + (index % 2 == 0 ? 8 : 0),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cyanGlow,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(
                              begin: 0.4,
                              end: 1.2,
                              duration: Duration(milliseconds: 400 + index * 100),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Messages Thread
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = chatMessages[index];
                  final isUser = msg.sender == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryPurple,
                                child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: GlassContainer(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: isUser
                                    ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                    : AppColors.surface.withValues(alpha: 0.5),
                                borderColor: isUser ? AppColors.cyanGlow.withValues(alpha: 0.5) : AppColors.glassBorder,
                                child: Text(
                                  msg.content,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (msg.suggestedActions != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: msg.suggestedActions!.map((act) {
                              return ActionChip(
                                label: Text(act),
                                backgroundColor: AppColors.surface,
                                labelStyle: const TextStyle(color: AppColors.cyanGlow, fontSize: 12, fontWeight: FontWeight.bold),
                                side: const BorderSide(color: AppColors.cyanGlow, width: 1),
                                onPressed: () {
                                  _msgController.text = act;
                                  _send();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Input Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      hintText: 'Ask AI Mentor anything about your skill matrix...',
                      controller: _msgController,
                      prefixIcon: Icons.chat_bubble_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassContainer(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: AppColors.primaryBlue,
                    onTap: _send,
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
