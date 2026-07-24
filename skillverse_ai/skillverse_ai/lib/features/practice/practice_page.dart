import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/skill_badge.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _isSubmitted = false;
  int _score = 0;

  final List<_PracticeQuestion> _questions = const [
    _PracticeQuestion(
      question: 'Which quantization technique allows loading a 70B parameter model on a single 24GB VRAM GPU with minimal perplexity degradation?',
      options: [
        'INT8 Native Precision Scaling',
        '4-bit NormalFloat (NF4) with QLoRA & Paged Optimizers',
        'FP16 Uniform Truncation',
        '8-bit Dynamic Vector Quantization'
      ],
      correctIndex: 1,
      explanation: 'NF4 (NormalFloat4) combined with QLoRA double quantization preserves optimal information density for zero-shot accuracy while reducing VRAM usage by ~4x.',
    ),
    _PracticeQuestion(
      question: 'In vLLM inference engine, what key optimization prevents CUDA memory fragmentation during long-context KV caching?',
      options: [
        'PagedAttention memory paging algorithm',
        'Tensor Parallelism sharding',
        'FlashAttention-2 tiling kernel',
        'Continuous batching without KV caching'
      ],
      correctIndex: 0,
      explanation: 'PagedAttention applies operating system virtual memory paging to KV cache memory, virtually eliminating fragmentation and enabling 2-4x higher batch capacity.',
    ),
    _PracticeQuestion(
      question: 'When implementing Speculative Decoding, what condition must the draft model satisfy?',
      options: [
        'Must use the exact same tokenizer & vocabulary as target LLM',
        'Must have identical layer count as target LLM',
        'Must run on CPU only',
        'Must use FP32 precision'
      ],
      correctIndex: 0,
      explanation: 'Speculative decoding relies on token verification against probability distributions; hence the draft model must share the identical tokenizer vocabulary.',
    ),
  ];

  void _submitAnswer() {
    if (_selectedOptionIndex == null) return;
    setState(() {
      _isSubmitted = true;
      if (_selectedOptionIndex == _questions[_currentQuestionIndex].correctIndex) {
        _score += 100;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _isSubmitted = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.cyanGlow),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.emeraldGreen),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.emeraldGreen, size: 54),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              const Text(
                'Simulation Completed!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_score / 300 Points!',
                style: const TextStyle(color: AppColors.cyanGlow, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your AI Digital Twin execution index increased by +4.2 points!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Return to Dashboard',
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentQuestionIndex = 0;
                    _selectedOptionIndex = null;
                    _isSubmitted = false;
                    _score = 0;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'AI Practice Room',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'LLM Fine-Tuning & Quantization Track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SkillBadge(label: 'Score: $_score XP', color: AppColors.cyanGlow),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentQuestionIndex + 1) / _questions.length,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Q${_currentQuestionIndex + 1}/${_questions.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Question Glass Card
              GlassContainer(
                hasGlow: true,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkillBadge(label: 'Scenario #409', color: AppColors.primaryBlue),
                    const SizedBox(height: 12),
                    Text(
                      currentQ.question,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Multiple Choice Options
              Expanded(
                child: ListView.builder(
                  itemCount: currentQ.options.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedOptionIndex == index;
                    final isCorrect = index == currentQ.correctIndex;

                    Color optionBorder = AppColors.glassBorder;
                    Color optionBg = AppColors.surface.withValues(alpha: 0.4);

                    if (_isSubmitted) {
                      if (isCorrect) {
                        optionBorder = AppColors.emeraldGreen;
                        optionBg = AppColors.emeraldGreen.withValues(alpha: 0.2);
                      } else if (isSelected) {
                        optionBorder = AppColors.roseError;
                        optionBg = AppColors.roseError.withValues(alpha: 0.2);
                      }
                    } else if (isSelected) {
                      optionBorder = AppColors.cyanGlow;
                      optionBg = AppColors.primaryBlue.withValues(alpha: 0.3);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        borderColor: optionBorder,
                        backgroundColor: optionBg,
                        padding: const EdgeInsets.all(16),
                        onTap: _isSubmitted ? null : () => setState(() => _selectedOptionIndex = index),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.cyanGlow : AppColors.surface,
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index),
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                currentQ.options[index],
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Explanation Box if Submitted
              if (_isSubmitted) ...[
                GlassContainer(
                  backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.cyanGlow),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currentQ.explanation,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit / Next Button
              GradientButton(
                width: double.infinity,
                text: _isSubmitted
                    ? (_currentQuestionIndex == _questions.length - 1 ? 'View Final Telemetry' : 'Next Scenario')
                    : 'Submit Solution',
                onPressed: _isSubmitted ? _nextQuestion : _submitAnswer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _PracticeQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
