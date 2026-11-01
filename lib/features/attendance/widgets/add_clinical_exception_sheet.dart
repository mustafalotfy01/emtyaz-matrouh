import 'package:flutter/material.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../roster/models/roster_entry.dart';
import '../models/student_clinical_daily_item.dart';

class AddClinicalExceptionSheet extends StatefulWidget {
  final StudentClinicalDailyItem item;
  final Future<bool> Function(String? note) onConfirm;

  const AddClinicalExceptionSheet({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentClinicalDailyItem item,
    required Future<bool> Function(String? note) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClinicalExceptionSheet(item: item, onConfirm: onConfirm),
    );
  }

  @override
  State<AddClinicalExceptionSheet> createState() => _AddClinicalExceptionSheetState();
}

class _AddClinicalExceptionSheetState extends State<AddClinicalExceptionSheet> {
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.item.effectiveShiftType;
    final isLong = shift == ShiftType.long;
    final isMorning = shift == ShiftType.morning;

    String effectDescription;
    if (isLong) {
      effectDescription = 'شيفت طويل (Long): يحضر الطالب الساعة 02:00 ظهراً (تأخير معتمد)';
    } else if (isMorning) {
      effectDescription = 'شيفت صباحي: عدم حضور الطالب لهذا الشيفت (استثناء معتمد)';
    } else {
      effectDescription = 'استثناء معتمد وموثق للطالب على شيفت اليوم';
    }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
                  color: AppDesignTokens.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: const Icon(Icons.emergency_rounded, color: AppDesignTokens.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إضافة عارضة (استثناء سريري)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.item.studentName} • ${widget.item.universityCode}',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Rule impact banner
          AppCard(
            variant: AppCardVariant.accentWarning,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppDesignTokens.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الأثر التدريبي المعتمد للعارضة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectDescription,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          AppInput(
            label: 'ملاحظة إضافية (اختياري)',
            hint: 'مثال: ظرف طارئ مثبت / إبلاغ مسبق...',
            controller: _noteController,
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
                  text: _isSubmitting ? 'جاري التسجيل...' : 'تأكيد العارضة',
                  icon: Icons.check_rounded,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final ok = await widget.onConfirm(
                            _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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
    );
  }
}
