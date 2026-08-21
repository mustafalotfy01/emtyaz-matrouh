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
    return NotificationCampaign(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString(),
      senderRole: json['sender_role']?.toString(),
      audienceType: json['audience_type'] ?? 'ALL_STUDENTS',
      audienceValue: json['audience_value']?.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'GENERAL',
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
      recipientCount: json['recipient_count'] is num ? (json['recipient_count'] as num).toInt() : 0,
      deviceCount: json['device_count'] is num ? (json['device_count'] as num).toInt() : 0,
      successCount: json['success_count'] is num ? (json['success_count'] as num).toInt() : 0,
      failureCount: json['failure_count'] is num ? (json['failure_count'] as num).toInt() : 0,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now())
          : DateTime.now(),
    );
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
