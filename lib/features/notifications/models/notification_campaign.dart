class NotificationCampaign {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderRole;
  final String audienceType;
  final String? audienceValue;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? metadata;
  final int recipientCount;
  final int deviceCount;
  final int successCount;
  final int failureCount;
  final DateTime createdAt;

  NotificationCampaign({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderRole,
    required this.audienceType,
    this.audienceValue,
    required this.title,
    required this.body,
    this.type = 'GENERAL',
    this.metadata,
    this.recipientCount = 0,
    this.deviceCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    required this.createdAt,
  });

  factory NotificationCampaign.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map<String, dynamic> ? (json['metadata'] as Map<String, dynamic>) : null;
    return NotificationCampaign(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? meta?['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? meta?['sender_name']?.toString(),
      senderRole: json['sender_role']?.toString() ?? meta?['sender_role']?.toString(),
      audienceType: json['audience_type'] ?? meta?['audience_type'] ?? 'ALL_STUDENTS',
      audienceValue: json['audience_value']?.toString() ?? meta?['audience_value']?.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      metadata: meta,
      recipientCount: json['recipient_count'] is num
          ? (json['recipient_count'] as num).toInt()
          : (meta?['recipient_count'] is num
              ? (meta!['recipient_count'] as num).toInt()
              : (meta?['recipients'] is num ? (meta!['recipients'] as num).toInt() : 0)),
      deviceCount: json['device_count'] is num
          ? (json['device_count'] as num).toInt()
          : (meta?['device_count'] is num ? (meta!['device_count'] as num).toInt() : 0),
      successCount: json['success_count'] is num
          ? (json['success_count'] as num).toInt()
          : (meta?['success_count'] is num ? (meta!['success_count'] as num).toInt() : 0),
      failureCount: json['failure_count'] is num
          ? (json['failure_count'] as num).toInt()
          : (meta?['failure_count'] is num ? (meta!['failure_count'] as num).toInt() : 0),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  factory NotificationCampaign.fromNotificationRow(Map<String, dynamic> row) {
    return NotificationCampaign.fromJson(row);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderRole != null) 'sender_role': senderRole,
      'audience_type': audienceType,
      if (audienceValue != null) 'audience_value': audienceValue,
      'title': title,
      'body': body,
      'type': type,
      if (metadata != null) 'metadata': metadata,
      'recipient_count': recipientCount,
      'device_count': deviceCount,
      'success_count': successCount,
      'failure_count': failureCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get audienceDisplayName {
    switch (audienceType) {
      case 'ALL_STUDENTS':
        return 'كل الطلاب (الدفعة كاملة)';
      case 'GROUP_A':
        return 'طلاب المجموعة A';
      case 'GROUP_B':
        return 'طلاب المجموعة B';
      case 'DEPARTMENT':
        return 'طلاب قسم: ${audienceValue ?? "القسم المحدد"}';
      case 'SPECIFIC_STUDENTS':
        return 'طلاب محددين ($recipientCount طالب)';
      default:
        return audienceType;
    }
  }
}
