import 'package:flutter/material.dart';

class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = 'GENERAL_ALERT',
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? 'إشعار جديد',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL_ALERT',
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now())
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  IconData get icon {
    switch (type) {
      case 'NEW_STUDENT_REGISTRATION':
        return Icons.person_add_alt_1_rounded;
      case 'ROSTER_APPROVED':
        return Icons.event_available_rounded;
      case 'PREFERENCES_REOPENED':
        return Icons.edit_calendar_rounded;
      case 'ATTENDANCE_ALERT':
        return Icons.location_on_outlined;
      case 'EVALUATION_ALERT':
        return Icons.star_border_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'NEW_STUDENT_REGISTRATION':
        return const Color(0xFF0284C7); // Sky Blue
      case 'ROSTER_APPROVED':
        return const Color(0xFF10B981); // Emerald Green
      case 'PREFERENCES_REOPENED':
        return const Color(0xFFF59E0B); // Amber
      case 'ATTENDANCE_ALERT':
        return const Color(0xFF8B5CF6); // Violet
      case 'EVALUATION_ALERT':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF0A7B83); // Primary Teal
    }
  }
}
