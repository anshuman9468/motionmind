import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../providers/app_providers.dart';

class OnboardingDetailsPage extends ConsumerStatefulWidget {
  const OnboardingDetailsPage({super.key});

  @override
  ConsumerState<OnboardingDetailsPage> createState() => _OnboardingDetailsPageState();
}

class _OnboardingDetailsPageState extends ConsumerState<OnboardingDetailsPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSynthesizing = false;

  // Controllers & Form variables
  final TextEditingController _nameController = TextEditingController(text: 'Alex Vance');
  double _age = 25;
  String _gender = 'Male';
  double _height = 175.0; // cm
  double _weight = 70.0;  // kg
  String _dominantHand = 'Right';
  String _learningGoal = 'Olympic Gold Medalist';
  
  final List<String> _selectedSkills = [];
  final List<String> _selectedEquipment = [];
  
  String _experienceLevel = 'Intermediate';
  String _practiceFrequency = 'Daily';

  final List<String> _skillOptions = const [
    'Powerlifting', 'Combat Boxing', 'Rhythm Dance', 'Guitar Dexterity', 'Vinyasa Flow', 'Chef Kinematics'
  ];

  final List<String> _equipmentOptions = const [
    'Olympic Barbell', 'Postural Sensor Grid', 'Heavy Punching Bag', 'Studio Mirror Suite'
  ];

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _startSynthesis();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _startSynthesis() async {
    setState(() => _isSynthesizing = true);
    
    // Save onboarding details state in Riverpod
    final details = {
      'name': _nameController.text.trim(),
      'age': _age.toInt(),
      'gender': _gender,
      'height': _height,
      'weight': _weight,
      'dominantHand': _dominantHand,
      'learningGoal': _learningGoal,
      'preferredSkills': _selectedSkills,
      'availableEquipment': _selectedEquipment,
      'experienceLevel': _experienceLevel,
      'practiceFrequency': _practiceFrequency,
    };
    
    ref.read(onboardingDetailsProvider.notifier).state = details;
    
    // Save profile to Firestore / Mock Database
    final db = ref.read(databaseServiceProvider);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid ?? 'usr_99';
    await db.saveUserProfile(uid, details);
    
    // Update local user state
    ref.read(userProvider.notifier).updateFromOnboarding(details);
    
    // Dynamic Digital Twin synthesis animation duration
    await Future.delayed(const Duration(milliseconds: 3200));
    
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSynthesizing) {
      return _buildSynthesisScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top progress bar indicator
              Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 5,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        gradient: isActive ? AppColors.primaryGradient : null,
                        color: isActive ? null : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                  ],
                ),
              ),

              // Bottom control actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textMuted),
                      label: const Text('Back', style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    const SizedBox(),
                  
                  GradientButton(
                    text: _currentStep == 3 ? 'Sync Digital Twin' : 'Continue',
                    icon: _currentStep == 3 ? Icons.auto_awesome_rounded : Icons.arrow_forward_ios_rounded,
                    onPressed: _nextStep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Let\'s begin your onboarding profile', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Telemetry setup', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        GlassTextField(
          hintText: 'Full Display Name',
          controller: _nameController,
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 24),
        
        // Age Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Age Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${_age.toInt()} years', style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          activeColor: AppColors.cyanGlow,
          inactiveColor: AppColors.surface,
          value: _age,
          min: 16,
          max: 80,
          onChanged: (val) => setState(() => _age = val),
        ),
        const SizedBox(height: 24),

        // Gender Selection
        const Text('Gender Identity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: ['Male', 'Female', 'Non-Binary'].map((g) {
            final isSel = _gender == g;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderColor: isSel ? AppColors.cyanGlow : AppColors.glassBorder,
                  backgroundColor: isSel ? AppColors.primaryBlue.withValues(alpha: 0.25) : null,
                  onTap: () => setState(() => _gender = g),
                  child: Text(g, textAlign: TextAlign.center, style: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Biometrics metrics calibration', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Physical Telemetry', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        // Height Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Height Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${_height.toInt()} cm', style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          activeColor: AppColors.cyanGlow,
          inactiveColor: AppColors.surface,
          value: _height,
          min: 120,
          max: 220,
          onChanged: (val) => setState(() => _height = val),
        ),
        const SizedBox(height: 20),

        // Weight Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Weight Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('${_weight.toInt()} kg', style: const TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          activeColor: AppColors.cyanGlow,
          inactiveColor: AppColors.surface,
          value: _weight,
          min: 30,
          max: 150,
          onChanged: (val) => setState(() => _weight = val),
        ),
        const SizedBox(height: 24),

        // Dominant Hand Selection
        const Text('Dominant Hand Telemetry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: ['Left', 'Right'].map((h) {
            final isSel = _dominantHand == h;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderColor: isSel ? AppColors.cyanGlow : AppColors.glassBorder,
                  backgroundColor: isSel ? AppColors.primaryBlue.withValues(alpha: 0.25) : null,
                  onTap: () => setState(() => _dominantHand = h),
                  child: Text(h, textAlign: TextAlign.center, style: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus domain target specs', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Skills & Ecosystem', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          const Text('Primary Learning Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GlassTextField(
            hintText: 'e.g. Lead Robotics Dev, Unicorn founder...',
            prefixIcon: Icons.flag_rounded,
            onChanged: (val) => setState(() => _learningGoal = val),
          ),
          const SizedBox(height: 20),

          const Text('Target Skill Matrices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillOptions.map((sk) {
              final isSel = _selectedSkills.contains(sk);
              return ChoiceChip(
                label: Text(sk),
                selected: isSel,
                selectedColor: AppColors.primaryBlue,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontSize: 12),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSkills.add(sk);
                    } else {
                      _selectedSkills.remove(sk);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Available Equipment Suite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipmentOptions.map((eq) {
              final isSel = _selectedEquipment.contains(eq);
              return ChoiceChip(
                label: Text(eq),
                selected: isSel,
                selectedColor: AppColors.primaryPurple,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontSize: 12),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEquipment.add(eq);
                    } else {
                      _selectedEquipment.remove(eq);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Telemetry habit calibrator', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Habits & Levels', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        const Text('Your Current Domain Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Column(
          children: ['Beginner', 'Intermediate', 'Expert'].map((lv) {
            final isSel = _experienceLevel == lv;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: GlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                borderColor: isSel ? AppColors.cyanGlow : AppColors.glassBorder,
                backgroundColor: isSel ? AppColors.primaryBlue.withValues(alpha: 0.25) : null,
                onTap: () => setState(() => _experienceLevel = lv),
                child: Text(lv, style: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        const Text('Target Telemetry Frequency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: ['Daily', 'Weekly', 'Bi-Weekly'].map((fr) {
            final isSel = _practiceFrequency == fr;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderColor: isSel ? AppColors.cyanGlow : AppColors.glassBorder,
                  backgroundColor: isSel ? AppColors.primaryBlue.withValues(alpha: 0.25) : null,
                  onTap: () => setState(() => _practiceFrequency = fr),
                  child: Text(fr, textAlign: TextAlign.center, style: TextStyle(color: isSel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSynthesisScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning Glowing Cog
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyanGlow.withValues(alpha: 0.4),
                      blurRadius: 36,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 54),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .rotate(duration: 2000.ms, curve: Curves.easeInOut),
              const SizedBox(height: 36),

              const Text(
                'Synthesizing Skill DNA...',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 12),

              const Text(
                'Calibrating 6-axis Digital Twin sensors and syncing telemetry vectors to Firestore cloud database.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
