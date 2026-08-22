import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../departments/models/department.dart';
import '../../departments/providers/department_provider.dart';
import '../models/fingerprint_request.dart';
import '../providers/fingerprint_provider.dart';

class FingerprintLogScreen extends ConsumerStatefulWidget {
  const FingerprintLogScreen({super.key});

  @override
  ConsumerState<FingerprintLogScreen> createState() => _FingerprintLogScreenState();
}

class _FingerprintLogScreenState extends ConsumerState<FingerprintLogScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(fingerprintRequestsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('سجل البصمة والحضور الفوري'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تحديث السجل',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(fingerprintRequestsProvider.notifier).loadRequests(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImmediateRequestDialog(context),
        backgroundColor: AppDesignTokens.primary,
        icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
        label: const Text('طلب بصمة فوري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: requestsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingSkeleton(itemCount: 4, height: 120),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorState(
              title: 'تعذر تحميل سجل البصمة',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.read(fingerprintRequestsProvider.notifier).loadRequests(),
            ),
          ),
          data: (requests) {
            final pendingCount = requests.where((r) => r.isPending).length;
            final confirmedCount = requests.where((r) => r.isConfirmed).length;
            final expiredCount = requests.where((r) => r.isExpired).length;

            final filtered = requests.where((r) {
              if (_selectedFilter == 'PENDING') return r.isPending;
              if (_selectedFilter == 'CONFIRMED') return r.isConfirmed;
              if (_selectedFilter == 'EXPIRED') return r.isExpired;
              return true;
            }).toList();

            return RefreshIndicator(
              onRefresh: () => ref.read(fingerprintRequestsProvider.notifier).loadRequests(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      variant: AppCardVariant.accentTeal,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fingerprint_rounded, color: AppDesignTokens.primary, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سجل البصمة والتواجد الميداني',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppDesignTokens.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'متابعة طلبات تأكيد الحضور والبصمة الحيوية للطلاب في الوقت الفعلي',
                                  style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('معلقة ⏳', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                                const SizedBox(height: 4),
                                Text('$pendingCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.warning)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('مؤكدة ✅', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                                const SizedBox(height: 4),
                                Text('$confirmedCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.success)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('منتهية ⏰', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                                const SizedBox(height: 4),
                                Text('$expiredCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.danger)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('الكل (${requests.length})', 'ALL'),
                          const SizedBox(width: 6),
                          _buildFilterChip('بانتظار التأكيد ($pendingCount)', 'PENDING'),
                          const SizedBox(width: 6),
                          _buildFilterChip('المؤكدة ($confirmedCount)', 'CONFIRMED'),
                          const SizedBox(width: 6),
                          _buildFilterChip('منتهية الصلاحية ($expiredCount)', 'EXPIRED'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (filtered.isEmpty)
                      const AppEmptyState(
                        title: 'لا توجد طلبات بصمة مسجلة',
                        message: 'يمكنك إرسال طلب تأكيد بصمة فوري للطلاب عبر الزر أدناه.',
                        icon: Icons.fingerprint_rounded,
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          return _buildRequestCard(context, req);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = filterKey);
      },
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, FingerprintRequest req) {
    AppBadgeVariant statusVariant = AppBadgeVariant.warning;
    if (req.isConfirmed) {
      statusVariant = AppBadgeVariant.success;
    } else if (req.isExpired) {
      statusVariant = AppBadgeVariant.danger;
    }

    final sentFormatted = DateFormat('yyyy/MM/dd - hh:mm a').format(req.sentAt);
    final confirmedFormatted = req.confirmedAt != null
        ? DateFormat('yyyy/MM/dd - hh:mm a').format(req.confirmedAt!)
        : null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: req.isConfirmed
                      ? AppDesignTokens.success.withOpacity(0.1)
                      : (req.isPending ? AppDesignTokens.warning.withOpacity(0.1) : AppDesignTokens.danger.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Icon(
                  req.isConfirmed
                      ? Icons.fingerprint_rounded
                      : (req.isPending ? Icons.pending_actions_rounded : Icons.timer_off_rounded),
                  color: req.isConfirmed
                      ? AppDesignTokens.success
                      : (req.isPending ? AppDesignTokens.warning : AppDesignTokens.danger),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    Text(
                      'الجمهور: ${req.audienceDisplay}',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: req.statusDisplay,
                variant: statusVariant,
                size: AppBadgeSize.small,
              ),
            ],
          ),

          if (req.notes != null && req.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req.notes!,
              style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
            ),
          ],

          const Divider(height: 16),

          // Details Matrix
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'وقت الإرسال: $sentFormatted',
                style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textMuted(context)),
              ),
              if (confirmedFormatted != null)
                Text(
                  'التأكيد: $confirmedFormatted',
                  style: const TextStyle(fontSize: 10.5, color: AppDesignTokens.success, fontWeight: FontWeight.bold),
                ),
            ],
          ),

          if (req.confirmedLatitude != null && req.confirmedLongitude != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppDesignTokens.info),
                const SizedBox(width: 4),
                Text(
                  'الموقع: (${req.confirmedLatitude!.toStringAsFixed(4)}, ${req.confirmedLongitude!.toStringAsFixed(4)})',
                  style: const TextStyle(fontSize: 10.5, color: AppDesignTokens.info),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showImmediateRequestDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ImmediateRequestBottomSheet(),
    );
  }
}

class _ImmediateRequestBottomSheet extends ConsumerStatefulWidget {
  const _ImmediateRequestBottomSheet();

  @override
  ConsumerState<_ImmediateRequestBottomSheet> createState() =>
      _ImmediateRequestBottomSheetState();
}

class _ImmediateRequestBottomSheetState
    extends ConsumerState<_ImmediateRequestBottomSheet> {
  String _audienceType = 'ALL';
  String? _selectedStudentId;
  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String _selectedShiftType = 'morning';
  final _titleController = TextEditingController(text: 'طلب بصمة تأكيد التواجد الفوري');
  final _notesController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final students = studentsAsync.maybeWhen(
      data: (list) => list
          .where((s) =>
              s.role == UserRole.student &&
              s.registrationStatus == RegistrationStatus.approved)
          .toList(),
      orElse: () => <UserProfile>[],
    );

    final deptsAsync = ref.watch(departmentsProvider);
    final departments = deptsAsync.maybeWhen(
      data: (list) => list.where((d) => d.isActive).toList(),
      orElse: () => <Department>[],
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fingerprint_rounded, color: AppDesignTokens.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'إرسال طلب بصمة فوري',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Audience Type
            AppDropdown<String>(
              label: 'الفئة المستهدفة *',
              value: _audienceType,
              items: const [
                AppDropdownItem(value: 'ALL', label: 'جميع طلاب الامتياز بالمستشفى 👥'),
                AppDropdownItem(value: 'CURRENT_SHIFT', label: 'طلاب الشيفت الحالي النشط الآن ⏱️'),
                AppDropdownItem(value: 'DEPARTMENT', label: 'حسب القسم السريري 🏥 (اختيار القسم)'),
                AppDropdownItem(value: 'SHIFT', label: 'حسب نوع الشيفت 🌅 (صباحي / سهر / نوبتجية)'),
                AppDropdownItem(value: 'SPECIFIC_STUDENT', label: 'طالب امتياز محدد 👤'),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _audienceType = val;
                    if (val == 'DEPARTMENT' && departments.isNotEmpty && _selectedDepartmentId == null) {
                      _selectedDepartmentId = departments.first.id;
                      _selectedDepartmentName = departments.first.nameAr;
                      _titleController.text = 'طلب بصمة - قسم ${departments.first.nameAr}';
                    } else if (val == 'CURRENT_SHIFT') {
                      _titleController.text = 'طلب بصمة تأكيد التواجد - الشيفت الحالي';
                    } else if (val == 'ALL') {
                      _titleController.text = 'طلب بصمة تأكيد التواجد الفوري';
                    }
                  });
                }
              },
            ),

            // Department Selector
            if (_audienceType == 'DEPARTMENT') ...[
              const SizedBox(height: 12),
              AppDropdown<String>(
                label: 'اختر القسم السريري *',
                value: _selectedDepartmentId,
                items: departments
                    .map((d) => AppDropdownItem(value: d.id, label: '${d.nameAr} (${d.nameEn})'))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDepartmentId = val;
                    final dept = departments.firstWhere((d) => d.id == val, orElse: () => departments.first);
                    _selectedDepartmentName = dept.nameAr;
                    _titleController.text = 'طلب بصمة - قسم ${dept.nameAr}';
                  });
                },
              ),
            ],

            // Shift Type Selector (Morning, Night, Long)
            if (_audienceType == 'SHIFT') ...[
              const SizedBox(height: 12),
              AppDropdown<String>(
                label: 'اختر نوع الشيفت المستهدف *',
                value: _selectedShiftType,
                items: const [
                  AppDropdownItem(value: 'morning', label: 'الشيفت الصباحي (08:00 ص - 02:00 م) 🌅'),
                  AppDropdownItem(value: 'long', label: 'نوبتجية كاملة / Long Shift (08:00 ص - 08:00 م) ⏱️'),
                  AppDropdownItem(value: 'night', label: 'شيفت السهر / Night Shift (08:00 م - 08:00 ص) 🌙'),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedShiftType = val;
                      String shiftNameAr = 'الصباحي';
                      if (val == 'night') shiftNameAr = 'السهر';
                      if (val == 'long') shiftNameAr = 'النوبتجية الكاملة';
                      _titleController.text = 'طلب بصمة - الشيفت $shiftNameAr';
                    });
                  }
                },
              ),
            ],

            // Specific Student Selector
            if (_audienceType == 'SPECIFIC_STUDENT') ...[
              const SizedBox(height: 12),
              AppDropdown<String>(
                label: 'اختر الطالب *',
                value: _selectedStudentId,
                items: students
                    .map((s) => AppDropdownItem(value: s.id, label: '${s.fullName} (${s.universityCode})'))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStudentId = val;
                    final student = students.firstWhere((s) => s.id == val, orElse: () => students.first);
                    _titleController.text = 'طلب بصمة للطالب ${student.fullName}';
                  });
                },
              ),
            ],

            const SizedBox(height: 12),

            AppInput(
              label: 'عنوان الإشعار *',
              controller: _titleController,
            ),

            const SizedBox(height: 12),

            AppInput(
              label: 'ملاحظات وتوجيهات للطلاب (اختياري)',
              hint: 'مثال: يرجى التوجه لمشرف القسم وتأكيد البصمة خلال 10 دقائق...',
              controller: _notesController,
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            AppButton(
              text: 'إرسال طلب البصمة فوراً',
              icon: Icons.send_rounded,
              variant: AppButtonVariant.primary,
              isLoading: _isSending,
              onPressed: () async {
                if (_audienceType == 'SPECIFIC_STUDENT' && _selectedStudentId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الطالب أولاً')),
                  );
                  return;
                }

                if (_audienceType == 'DEPARTMENT' && _selectedDepartmentId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار القسم السريري أولاً')),
                  );
                  return;
                }

                setState(() => _isSending = true);

                String effectiveAudience = _audienceType;
                if (_audienceType == 'DEPARTMENT') {
                  effectiveAudience = 'DEPARTMENT:${_selectedDepartmentName ?? _selectedDepartmentId}';
                } else if (_audienceType == 'SHIFT') {
                  effectiveAudience = 'SHIFT:$_selectedShiftType';
                }

                try {
                  await ref.read(fingerprintRequestsProvider.notifier).sendImmediateRequest(
                        audienceType: effectiveAudience,
                        targetStudentId: _selectedStudentId,
                        title: _titleController.text.trim(),
                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                      );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال طلب البصمة الفوري بنجاح!'),
                        backgroundColor: AppDesignTokens.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppDesignTokens.danger),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSending = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
