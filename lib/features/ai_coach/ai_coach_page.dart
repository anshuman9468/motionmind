import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _isSending = false;

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final replyFuture = ref
        .read(aiCoachChatProvider.notifier)
        .sendMessage(text);
    _msgController.clear();
    _scrollToBottom();
    await replyFuture;
    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiCoachChatProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MotionMind Health Companion',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'A relatable companion for your wellbeing.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: .5),
                      ),
                    ),
                    child: const Text(
                      'HEALTH CHAT',
                      style: TextStyle(
                        color: AppColors.cyanGlow,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassContainer(
                padding: const EdgeInsets.all(14),
                borderRadius: AppColors.radiusMedium,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'General wellness guidance only — not a diagnosis. For severe or sudden symptoms, seek urgent medical care.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message.sender == 'user';
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primaryBlue.withValues(alpha: .2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isUser
                              ? AppColors.primaryBlue.withValues(alpha: .55)
                              : AppColors.outline,
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      hintText: 'Ask about your health or training',
                      controller: _msgController,
                      prefixIcon: Icons.edit_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    child: GlassContainer(
                      onTap: _isSending ? null : () => _send(),
                      padding: const EdgeInsets.all(15),
                      borderRadius: AppColors.radiusMedium,
                      backgroundColor: AppColors.primaryBlue,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnAccent,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppColors.textOnAccent,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/practice'),
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('Start a practice session'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
