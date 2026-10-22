import 'package:flutter/material.dart';

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double progress; // 0.0 to 1.0
  final bool isUnlocked;
  final int points;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.progress,
    required this.isUnlocked,
    required this.points,
  });
}
