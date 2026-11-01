import 'package:flutter/material.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../roster/models/roster_entry.dart';
import '../models/student_clinical_daily_item.dart';

class AddCompensationSheet extends StatefulWidget {
  final StudentClinicalDailyItem? item;
  final List<StudentClinicalDailyItem>? allStudents;
  final Future<bool> Function({
    required String studentId,
    required DateTime compensationDate,
    required ShiftType shiftType,
    DateTime? originalDate,
    String? reason,
    String? notes,
  }) onConfirm;

  const AddCompensationSheet({
    super.key,
    this.item,
    this.allStudents,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    StudentClinicalDailyItem? item,
    List<StudentClinicalDailyItem>? allStudents,
    required Future<bool> Function({
      required String studentId,
      required DateTime compensationDate,
      required ShiftType shiftType,
      DateTime? originalDate,
      String? reason,
      String? notes,
    }) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCompensationSheet(
        item: item,
        allStudents: allStudents,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<AddCompensationSheet> createState() => _AddCompensationSheetState();
}

class _AddCompensationSheetState extends State<AddCompensationSheet> {
  String? _selectedStudentId;
  late DateTime _compDate;
  DateTime? _originalDate;
  ShiftType _shiftType = ShiftType.morning;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.item?.studentId ??
        (widget.allStudents?.isNotEmpty == true ? widget.allStudents!.first.studentId : null);
    // Default compensation to tomorrow or current date
    _compDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignTokens.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  child: const Icon(Icons.published_with_changes_rounded, color: AppDesignTokens.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة تعويض شيفت (Compensation)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'جدولة تعويض غياب أو تأخير معتمد بالروستر',
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.slateMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Student selection if not preselected
            if (widget.item == null && widget.allStudents != null) ...[
              AppDropdown<String>(
                label: 'الطالب المستحق للتعويض',
                value: _selectedStudentId,
                items: widget.allStudents!.map((s) {
                  return AppDropdownItem(
                    value: s.studentId,
                    label: '${s.studentName} (${s.universityCode})',
                    icon: Icons.person_rounded,
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudentId = val),
              ),
              const SizedBox(height: 14),
            ] else if (widget.item != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 20, color: AppDesignTokens.primary),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.item!.studentName} (${widget.item!.universityCode})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Target Compensation Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _compDate,
                  firstDate: DateTime(2025, 1, 1),
                  lastDate: DateTime(2030, 12, 31),
                );
                if (picked != null && mounted) {
                  setState(() => _compDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppDesignTokens.border(context)),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  color: AppDesignTokens.surfaceMuted(context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppDesignTokens.success, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'تاريخ يوم التعويض: ${_formatDate(_compDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Text('تغيير التاريخ', style: TextStyle(color: AppDesignTokens.primary, fontSize: 12)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Original Absence Date (Optional)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _originalDate ?? DateTime.now(),
                  firstDate: DateTime(2025, 1, 1),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => _originalDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppDesignTokens.border(context)),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  color: AppDesignTokens.surfaceMuted(context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, color: AppDesignTokens.warning, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _originalDate != null
                              ? 'عوضاً عن غياب يوم: ${_formatDate(_originalDate!)}'
                              : 'تحديد يوم الغياب الأصلي (اختياري)',
                          style: TextStyle(
                            fontWeight: _originalDate != null ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _originalDate != null ? 'تعديل' : 'اختيار',
                      style: const TextStyle(color: AppDesignTokens.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Shift Type Selection
            AppDropdown<ShiftType>(
              label: 'نوع شيفت التعويض المطلوب',
              value: _shiftType,
              items: const [
                AppDropdownItem(value: ShiftType.morning, label: 'صباحي (08:00 - 14:00)', icon: Icons.wb_sunny_rounded),
                AppDropdownItem(value: ShiftType.long, label: 'طويل Long (08:00 - 20:00)', icon: Icons.schedule_rounded),
                AppDropdownItem(value: ShiftType.evening, label: 'مسائي (14:00 - 20:00)', icon: Icons.nights_stay_rounded),
                AppDropdownItem(value: ShiftType.night, label: 'سهر Night (20:00 - 08:00)', icon: Icons.bedtime_rounded),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _shiftType = val);
              },
            ),

            const SizedBox(height: 14),

            AppInput(
              label: 'سبب التعويض',
              hint: 'مثال: تعويض غياب معتمد / نوبتجية استعاضة...',
              controller: _reasonController,
            ),

            const SizedBox(height: 12),

            AppInput(
              label: 'ملاحظات إضافية (اختياري)',
              hint: 'أي توجيهات سريرية تخص نوبتجية التعويض...',
              controller: _notesController,
              maxLines: 2,
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'إلغاء',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: _isSubmitting ? 'جاري الحفظ...' : 'تأكيد إضافة التعويض',
                    icon: Icons.check_circle_outline_rounded,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting || _selectedStudentId == null
                        ? null
                        : () async {
                            setState(() => _isSubmitting = true);
                            final ok = await widget.onConfirm(
                              studentId: _selectedStudentId!,
                              compensationDate: _compDate,
                              shiftType: _shiftType,
                              originalDate: _originalDate,
                              reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
                              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                            );
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              if (ok) Navigator.pop(context);
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
