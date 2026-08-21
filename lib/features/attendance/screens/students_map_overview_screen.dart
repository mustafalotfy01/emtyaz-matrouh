import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/coming_soon_screen.dart';

class StudentsMapOverviewScreen extends StatelessWidget {
  const StudentsMapOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'خريطة توزيع مقار سكن الطلاب',
      subtitle: 'يتم حالياً ربط نظم الخرائط الجغرافية لحساب النطاقات السكنية وبُعد الطلاب عن المستشفيات بدقة.',
      icon: Icons.map_rounded,
      accentColor: AppColors.primaryTeal,
      showBackButton: true,
    );
  }
}
