import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/attendance_record.dart';
import '../models/clinical_compensation_model.dart';
import '../models/clinical_exception_model.dart';
import '../models/clinical_permission_model.dart';
import '../providers/clinical_training_provider.dart';

class StudentClinicalProfileScreen extends ConsumerWidget {
  final String studentId;
  final String studentName;
  final String universityCode;
  final String? avatarUrl;

  const StudentClinicalProfileScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.universityCode,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentClinicalProfileProvider(studentId));
    final currentUser = ref.watch(authProvider).user;
    final isStaff = currentUser?.role == UserRole.leader ||
        currentUser?.role == UserRole.superAdmin ||
        currentUser?.role == UserRole.evaluatingDoctor;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('الملف التدريبي الإكلينيكي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(studentClinicalProfileProvider(studentId)),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('حدث خطأ في تحميل السجل السريري: $err'),
          ),
        ),
        data: (data) {
          final profile = data['profile'] as Map<String, dynamic>?;
          final groupMap = profile?['student_groups'] as Map<String, dynamic>?;
          final groupName = groupMap?['name']?.toString() ?? 'غير محدد';
          final deptName = groupMap?['departments']?['name_ar']?.toString() ?? 'قسم الطوارئ والعناية';
          final doctorName = groupMap?['profiles']?['full_name']?.toString() ?? 'المشرف الطبي';

          final attendance = (data['attendance'] as List<AttendanceRecord>?) ?? [];
          final exceptions = (data['exceptions'] as List<ClinicalExceptionModel>?) ?? [];
          final permissions = (data['permissions'] as List<ClinicalPermissionModel>?) ?? [];
          final compensations = (data['compensations'] as List<ClinicalCompensationModel>?) ?? [];

          final presentCount = attendance.where((a) => a.status == AttendanceStatus.present || a.status == AttendanceStatus.late).length;
          final absentCount = attendance.where((a) => a.status == AttendanceStatus.absent).length;
          final dueCompCount = compensations.where((c) => c.status == CompensationStatus.due).length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── 1. Student Clinical Identity Card ───────────────────────
              AppCard(
                variant: AppCardVariant.accentTeal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AppAvatar(
                      name: studentName,
                      imageUrl: avatarUrl,
                      size: AppAvatarSize.large,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'كود الطالب: $universityCode',
                            style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              AppBadge(label: groupName, variant: AppBadgeVariant.primary, size: AppBadgeSize.small),
                              AppBadge(label: deptName, variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المشرف الطبي: $doctorName',
                            style: const TextStyle(fontSize: 11, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Clinical Metrics KPI Bar ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(context, 'الحضور', '$presentCount', AppDesignTokens.success),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(context, 'الغياب', '$absentCount', AppDesignTokens.danger),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(context, 'العارضة', '${exceptions.length}', AppDesignTokens.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(context, 'ترك عمل', '${permissions.length}', AppDesignTokens.info),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(context, 'تعويض مستحق', '$dueCompCount', const Color(0xFF8B5CF6)),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 3. Exceptions (العارضة) ──────────────────────────────────
              AppSectionHeader(
                title: 'سجل العارضة والاستثناءات السريرية',
                subtitle: 'أثر الاستثناء على الشيفت المعتمد',
                actionText: '${exceptions.length} عارضة',
              ),
              const SizedBox(height: 8),

              if (exceptions.isEmpty)
                _buildEmptyNotice(context, 'لا توجد استثناءات عارضة مسجلة للطالب')
              else
                ...exceptions.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.warning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.emergency_rounded, color: AppDesignTokens.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${e.exceptionDate.year}-${e.exceptionDate.month.toString().padLeft(2, '0')}-${e.exceptionDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    AppBadge(
                                      label: e.shiftType.shortCode,
                                      variant: AppBadgeVariant.warning,
                                      size: AppBadgeSize.small,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  e.impactDescriptionAr,
                                  style: const TextStyle(fontSize: 12, color: AppDesignTokens.warning, fontWeight: FontWeight.bold),
                                ),
                                if (e.note != null && e.note!.isNotEmpty)
                                  Text(
                                    'ملاحظة: ${e.note}',
                                    style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                  ),
                              ],
                            ),
                          ),
                          if (e.recordedByName != null)
                            Text(
                              e.recordedByName!,
                              style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 18),

              // ── 4. Early Leave Permissions (أذونات ترك العمل) ───────────
              AppSectionHeader(
                title: 'أذونات ترك العمل والانصراف المبكر',
                subtitle: 'أذونات موثقة مع الحفاظ على الحضور الصباحي',
                actionText: '${permissions.length} إذن',
              ),
              const SizedBox(height: 8),

              if (permissions.isEmpty)
                _buildEmptyNotice(context, 'لا توجد أذونات ترك عمل مسجلة')
              else
                ...permissions.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.info.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.exit_to_app_rounded, color: AppDesignTokens.info, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${p.permissionDate.year}-${p.permissionDate.month.toString().padLeft(2, '0')}-${p.permissionDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'انصراف: ${p.leaveTime}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.info),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.reason ?? 'إذن موثق ومصرح به',
                                  style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          if (p.grantedByName != null)
                            Text(
                              'بواسطة: ${p.grantedByName}',
                              style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 18),

              // ── 5. Compensations (التعويضات) ───────────────────────────
              AppSectionHeader(
                title: 'سجل التعويضات السريرية',
                subtitle: 'نوبتجيات الاستعاضة ومتابعة التنفيذ',
                actionText: '${compensations.length} تعويض',
              ),
              const SizedBox(height: 8),

              if (compensations.isEmpty)
                _buildEmptyNotice(context, 'لا توجد تعويضات مسجلة للطالب')
              else
                ...compensations.map((c) {
                  final isDue = c.status == CompensationStatus.due;
                  final isDone = c.status == CompensationStatus.completed;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isDone ? AppDesignTokens.success : AppDesignTokens.primary).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                  color: isDone ? AppDesignTokens.success : AppDesignTokens.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'يوم التعويض: ${c.compensationDate.year}-${c.compensationDate.month.toString().padLeft(2, '0')}-${c.compensationDate.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        AppBadge(
                                          label: c.status.displayNameAr,
                                          variant: isDone
                                              ? AppBadgeVariant.success
                                              : (c.status == CompensationStatus.cancelled
                                                  ? AppBadgeVariant.neutral
                                                  : AppBadgeVariant.warning),
                                          size: AppBadgeSize.small,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'شيفت التعويض: ${c.shiftType.displayNameAr}',
                                      style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                                    ),
                                    if (c.originalDate != null)
                                      Text(
                                        'عوضاً عن غياب يوم: ${c.originalDate!.year}-${c.originalDate!.month.toString().padLeft(2, '0')}-${c.originalDate!.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 11, color: AppDesignTokens.warning),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isStaff && isDue) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('تأكيد التنفيذ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final repo = ref.read(clinicalTrainingRepositoryProvider);
                                    await repo.updateCompensationStatus(
                                      compensationId: c.id,
                                      status: CompensationStatus.completed,
                                    );
                                    ref.invalidate(studentClinicalProfileProvider(studentId));
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  child: const Text('إلغاء التعويض', style: TextStyle(fontSize: 12, color: AppDesignTokens.danger)),
                                  onPressed: () async {
                                    final repo = ref.read(clinicalTrainingRepositoryProvider);
                                    await repo.updateCompensationStatus(
                                      compensationId: c.id,
                                      status: CompensationStatus.cancelled,
                                    );
                                    ref.invalidate(studentClinicalProfileProvider(studentId));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        border: Border.all(color: AppDesignTokens.border(context)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppDesignTokens.textSecondary(context))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotice(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.surfaceMuted(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
        ),
      ),
    );
  }
}
