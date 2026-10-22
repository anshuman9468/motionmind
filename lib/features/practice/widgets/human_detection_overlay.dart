import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../models/skill_biomechanics.dart';

class HumanDetectionOverlay extends StatelessWidget {
  final HumanTrackingPayload payload;
  final Function(String personId) onSelectPerson;

  const HumanDetectionOverlay({
    super.key,
    required this.payload,
    required this.onSelectPerson,
  });

  @override
  Widget build(BuildContext context) {
    if (!payload.humanDetected ||
        payload.trackingState == HumanDetectionState.searchingForHuman) {
      return _buildSearchingOverlay();
    }

    if (payload.trackingState == HumanDetectionState.bodyNotClear) {
      return _buildBodyNotClearOverlay();
    }

    return Stack(
      children: [
        // Human Locked Status Chip (Top Center)
        Positioned(
          top: 105,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emeraldGreen, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.emeraldGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'HUMAN LOCKED ✓  (${(payload.trackingConfidence * 100).toInt()}% CONFIDENCE)',
                    style: const TextStyle(
                      color: AppColors.emeraldGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Multiple People Detection Selector Bar
        if (payload.multiplePeopleCount > 1 ||
            payload.trackingState == HumanDetectionState.multiplePeopleDetected)
          Positioned(
            top: 145,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cyanGlow.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        color: AppColors.cyanGlow,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'MULTIPLE PEOPLE DETECTED — SELECT PRIMARY USER',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(payload.multiplePeopleCount, (idx) {
                      final id = 'primary_user_${idx + 1}';
                      final isSel = payload.selectedPersonId == id;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('User #${idx + 1}'),
                            selected: isSel,
                            selectedColor: AppColors.primaryBlue,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              onSelectPerson(id);
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyanGlow.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.cyanGlow.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: AppColors.cyanGlow,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.cyanGlow.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'SEARCHING FOR HUMAN...\nStep in front of camera to begin biomechanical pose lock',
              maxLines: 3,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.cyanGlow,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyNotClearOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'BODY NOT CLEAR — MOVE FULLY INTO FRAME\nEnsure head, torso, knees, and feet are visible.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
