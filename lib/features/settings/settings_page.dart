import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_button.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoSyncTwin = true;
  bool _pushNotifications = true;
  bool _hapticFeedback = true;

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Text(
            'Gemini health companion',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'For security, the Gemini key is configured on the FastAPI backend, not stored in the app. Set GEMINI_API_KEY in the backend terminal and restart the server. The key is never bundled into the APK.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            GradientButton(
              text: 'Got it',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // AI Telemetry Section
            const _SectionTitle(title: 'COACHING & PRIVACY'),
            const SizedBox(height: 8),
            GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      activeThumbColor: AppColors.cyanGlow,
                      title: const Text(
                        'Save practice insights',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Keep your movement findings available for future sessions',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _autoSyncTwin,
                      onChanged: (val) => setState(() => _autoSyncTwin = val),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.key_rounded,
                        color: AppColors.cyanGlow,
                      ),
                      title: const Text(
                        'Gemini health companion',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Configure GEMINI_API_KEY on the backend to enable health chat',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showApiKeyDialog,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notifications & Audio Section
            const _SectionTitle(title: 'NOTIFICATIONS & HAPTICS'),
            const SizedBox(height: 8),
            GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      activeThumbColor: AppColors.cyanGlow,
                      title: const Text(
                        'Practice reminders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Get reminders to return to your training routine',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _pushNotifications,
                      onChanged: (val) =>
                          setState(() => _pushNotifications = val),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      activeThumbColor: AppColors.cyanGlow,
                      title: const Text(
                        'Touch feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Use small vibrations for important actions',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _hapticFeedback,
                      onChanged: (val) => setState(() => _hapticFeedback = val),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Information Section
            const _SectionTitle(title: 'ABOUT & LEGAL'),
            const SizedBox(height: 8),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MotionMind version',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'v3.24.0-pro',
                        style: TextStyle(
                          color: AppColors.cyanGlow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Movement coaching for sports and gym practice.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}
