import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/gradient_button.dart';
import '../providers/app_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController(text: 'alex.vance@skillverse.ai');
  final TextEditingController _passwordController = TextEditingController(text: '••••••••••••');
  final TextEditingController _nameController = TextEditingController(text: 'Alex Vance');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _handleEmailAuth() async {
    setState(() => _isLoading = true);
    final auth = ref.read(authServiceProvider);
    
    try {
      if (_tabController.index == 0) {
        // Sign In
        await auth.signInWithEmail(_emailController.text.trim(), _passwordController.text.trim());
      } else {
        // Create Account
        await auth.signUpWithEmail(_emailController.text.trim(), _passwordController.text.trim());
      }
      if (mounted) {
        context.go('/onboarding-details');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e'), backgroundColor: AppColors.roseError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialAuth(String provider) async {
    setState(() => _isLoading = true);
    final auth = ref.read(authServiceProvider);
    
    try {
      if (provider == 'google') {
        await auth.signInWithGoogle();
      } else if (provider == 'apple') {
        await auth.signInWithApple();
      } else {
        await auth.signInAnonymously(); // Guest fallback
      }
      if (mounted) {
        context.go('/onboarding-details');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$provider sign in failed: $e'), backgroundColor: AppColors.roseError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Badge
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanGlow.withValues(alpha: 0.35),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),

                  const Text(
                    'Welcome to SkillVerse AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to sync your AI Digital Twin telemetry',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Glass Tab Container
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Tab Selector
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textMuted,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Create Account'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Inputs
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            final isSignUp = _tabController.index == 1;
                            return Column(
                              children: [
                                if (isSignUp) ...[
                                  GlassTextField(
                                    hintText: 'Full Name',
                                    controller: _nameController,
                                    prefixIcon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                GlassTextField(
                                  hintText: 'Email Address',
                                  controller: _emailController,
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                GlassTextField(
                                  hintText: 'Password',
                                  controller: _passwordController,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                GradientButton(
                                  width: double.infinity,
                                  text: isSignUp ? 'Create Free Account' : 'Sign In to SkillVerse',
                                  isLoading: _isLoading,
                                  onPressed: _handleEmailAuth,
                                ),
                                const SizedBox(height: 16),

                                // Guest Login
                                TextButton(
                                  onPressed: () => _handleSocialAuth('guest'),
                                  child: const Text(
                                    'Continue as Guest',
                                    style: TextStyle(color: AppColors.cyanGlow, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Social Logins
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.glassBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.glassBorder)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialIconButton(
                        icon: Icons.g_mobiledata_rounded,
                        onTap: () => _handleSocialAuth('google'),
                      ),
                      const SizedBox(width: 16),
                      _SocialIconButton(
                        icon: Icons.apple_rounded,
                        onTap: () => _handleSocialAuth('apple'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
