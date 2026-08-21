import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color text;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.text,
    this.icon,
  });

  factory StatusBadge.present() {
    return const StatusBadge(
      label: 'حاضر 🟢',
      bg: AppColors.successLight,
      text: AppColors.success,
    );
  }

  factory StatusBadge.late() {
    return const StatusBadge(
      label: 'متأخر 🟠',
      bg: AppColors.warningLight,
      text: AppColors.warning,
    );
  }

  factory StatusBadge.absent() {
    return const StatusBadge(
      label: 'غائب 🔴',
      bg: AppColors.dangerLight,
      text: AppColors.danger,
    );
  }

  factory StatusBadge.pending() {
    return const StatusBadge(
      label: 'قيد المراجعة ⏳',
      bg: AppColors.infoLight,
      text: AppColors.info,
    );
  }

  factory StatusBadge.approved() {
    return const StatusBadge(
      label: 'معتمد ✅',
      bg: AppColors.successLight,
      text: AppColors.success,
    );
  }

  factory StatusBadge.rejected() {
    return const StatusBadge(
      label: 'مرفوض ❌',
      bg: AppColors.dangerLight,
      text: AppColors.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
