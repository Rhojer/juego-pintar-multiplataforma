import 'package:flutter/material.dart';

@immutable
class SpecialModeData {
  const SpecialModeData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.bannerText,
    required this.badgeColor,
    required this.textColor,
    required this.celebrationText,
    this.hintReminder,
    this.ruleHint,
  });

  final String id;
  final String name;
  final String emoji;
  final String subtitle;
  final String bannerText;
  final Color badgeColor;
  final Color textColor;
  final String celebrationText;
  final String? hintReminder;
  final String? ruleHint;

  static Color _parseColor(dynamic val, Color fallback) {
    if (val == null) return fallback;
    if (val is int) return Color(val);
    if (val is String) {
      final hex = val.replaceAll('#', '');
      if (hex.length == 6) {
        final parsed = int.tryParse('FF$hex', radix: 16);
        if (parsed != null) return Color(parsed);
      } else if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }
    return fallback;
  }

  factory SpecialModeData.fromJson(Map<String, dynamic> json) {
    return SpecialModeData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎉',
      subtitle: json['subtitle'] as String? ?? '',
      bannerText: json['bannerText'] as String? ?? '',
      badgeColor: _parseColor(json['badgeColor'], const Color(0xFF29B6F6)),
      textColor: _parseColor(json['textColor'], Colors.white),
      celebrationText: json['celebrationText'] as String? ?? '',
      hintReminder: json['hintReminder'] as String?,
      ruleHint: json['ruleHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'subtitle': subtitle,
    'bannerText': bannerText,
    'badgeColor': '#${badgeColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'textColor': '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'celebrationText': celebrationText,
    'hintReminder': hintReminder,
    'ruleHint': ruleHint,
  };
}
