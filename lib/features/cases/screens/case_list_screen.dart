import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/coming_soon_screen.dart';

class CaseListScreen extends StatelessWidget {
  const CaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'تسليم واستلام الحالات التمريضية (Nursing Handover)',
      subtitle: 'يتم حالياً تطوير وتجهيز نظام التسليم والتسلم السريري بين أطقم التمريض بالاسم والتشخيص الطبي.',
      icon: Icons.sync_alt_rounded,
      accentColor: AppColors.primaryTeal,
      showBackButton: true,
    );
  }
}
