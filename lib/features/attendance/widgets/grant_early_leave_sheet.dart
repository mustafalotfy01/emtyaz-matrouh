import 'package:flutter/material.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../models/student_clinical_daily_item.dart';

class GrantEarlyLeaveSheet extends StatefulWidget {
  final StudentClinicalDailyItem item;
  final Future<bool> Function(String leaveTime, String? reason) onConfirm;

  const GrantEarlyLeaveSheet({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentClinicalDailyItem item,
    required Future<bool> Function(String leaveTime, String? reason) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrantEarlyLeaveSheet(item: item, onConfirm: onConfirm),
    );
  }

  @override
  State<GrantEarlyLeaveSheet> createState() => _GrantEarlyLeaveSheetState();
}

class _GrantEarlyLeaveSheetState extends State<GrantEarlyLeaveSheet> {
  late TimeOfDay _leaveTime;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _leaveTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final hour = _leaveTime.hour.toString().padLeft(2, '0');
    final minute = _leaveTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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
                  color: AppDesignTokens.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: AppDesignTokens.info, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إذن ترك عمل (انصراف مبكر)',
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

          AppCard(
            variant: AppCardVariant.accentTeal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppDesignTokens.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لا يلغي هذا الإذن الحضور الصباحي؛ يوثق حضور الطالب ومنحه إذناً بالمغادرة في وقت محدد.',
                    style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textPrimary(context), height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time Picker Tile
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _leaveTime,
              );
              if (picked != null && mounted) {
                setState(() => _leaveTime = picked);
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
                      const Icon(Icons.access_time_rounded, color: AppDesignTokens.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'وقت المغادرة: $_formattedTime',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const Text('تغيير الوقت', style: TextStyle(color: AppDesignTokens.primary, fontSize: 12)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          AppInput(
            label: 'سبب المغادرة (اختياري)',
            hint: 'مثال: عذر مرضي / استدعاء طارئ...',
            controller: _reasonController,
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
                  text: _isSubmitting ? 'جاري التسجيل...' : 'تأكيد منح الإذن',
                  icon: Icons.check_circle_rounded,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final ok = await widget.onConfirm(
                            _formattedTime,
                            _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
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
