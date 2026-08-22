class FingerprintRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String audienceType; // 'ALL', 'GROUP_A', 'GROUP_B', 'SPECIFIC_STUDENT'
  final String? targetStudentId;
  final String? targetStudentName;
  final String? targetStudentCode;
  final String title;
  final String? notes;
  final String status; // 'pending', 'confirmed', 'expired'
  final DateTime sentAt;
  final DateTime? confirmedAt;
  final double? confirmedLatitude;
  final double? confirmedLongitude;
  final Map<String, dynamic> deviceMetadata;

  FingerprintRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.audienceType,
    this.targetStudentId,
    this.targetStudentName,
    this.targetStudentCode,
    required this.title,
    this.notes,
    required this.status,
    required this.sentAt,
    this.confirmedAt,
    this.confirmedLatitude,
    this.confirmedLongitude,
    this.deviceMetadata = const {},
  });

  static const int expirationDurationSeconds = 300; // 5 minutes limit

  bool get isConfirmed => status == 'confirmed';
  bool get isExpiredByTime {
    if (status == 'confirmed') return false;
    final diff = DateTime.now().difference(sentAt).inSeconds;
    return diff >= expirationDurationSeconds;
  }
  bool get isExpired => status == 'expired' || isExpiredByTime;
  bool get isPending => status == 'pending' && !isExpiredByTime;

  int get remainingSeconds {
    if (status == 'confirmed') return 0;
    final elapsed = DateTime.now().difference(sentAt).inSeconds;
    final left = expirationDurationSeconds - elapsed;
    return left > 0 ? left : 0;
  }

  String get remainingTimeFormatted {
    final secs = remainingSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get audienceDisplay {
    if (audienceType.startsWith('DEPARTMENT:')) {
      final name = audienceType.substring('DEPARTMENT:'.length);
      return 'قسم $name 🏥';
    }
    if (audienceType.startsWith('SHIFT:')) {
      final s = audienceType.substring('SHIFT:'.length);
      switch (s) {
        case 'morning':
          return 'الشيفت الصباحي 🌅';
        case 'night':
          return 'شيفت السهر 🌙';
        case 'long':
          return 'نوبتجية كاملة ⏱️';
        default:
          return 'شيفت $s';
      }
    }
    switch (audienceType) {
      case 'ALL':
        return 'جميع طلاب الامتياز بالمستشفى 👥';
      case 'CURRENT_SHIFT':
        return 'طلاب الشيفت الحالي ⏱️';
      case 'SPECIFIC_STUDENT':
        return targetStudentName != null ? 'طالب: $targetStudentName 👤' : 'طالب محدد 👤';
      default:
        return audienceType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'confirmed':
        return 'تم تأكيد البصمة ✅';
      case 'expired':
        return 'منتهي الصلاحية ⏰';
      case 'pending':
      default:
        return 'بانتظار التأكيد ⏳';
    }
  }

  factory FingerprintRequest.fromJson(Map<String, dynamic> json) {
    String sName = 'إدارة الكلية';
    if (json['sender'] != null && json['sender'] is Map<String, dynamic>) {
      sName = json['sender']['full_name'] ?? sName;
    }

    String? tName;
    String? tCode;
    if (json['target_student'] != null && json['target_student'] is Map<String, dynamic>) {
      tName = json['target_student']['full_name'];
      tCode = json['target_student']['university_code'];
    }

    return FingerprintRequest(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? sName,
      audienceType: json['audience_type'] ?? 'ALL',
      targetStudentId: json['target_student_id'],
      targetStudentName: json['target_student_name'] ?? tName,
      targetStudentCode: json['target_student_code'] ?? tCode,
      title: json['title'] ?? 'طلب تأكيد التواجد والبصمة',
      notes: json['notes'],
      status: json['status'] ?? 'pending',
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at']) ?? DateTime.now() : DateTime.now(),
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at']) : null,
      confirmedLatitude: json['confirmed_latitude'] != null ? (json['confirmed_latitude'] as num).toDouble() : null,
      confirmedLongitude: json['confirmed_longitude'] != null ? (json['confirmed_longitude'] as num).toDouble() : null,
      deviceMetadata: json['device_metadata'] is Map<String, dynamic> ? json['device_metadata'] : {},
    );
  }
}
