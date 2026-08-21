import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ios/app_button.dart';
import '../../../core/widgets/ios/app_card.dart';
import '../../../core/widgets/ios/app_section_header.dart';
import '../providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceCheckinScreen extends ConsumerStatefulWidget {
  const AttendanceCheckinScreen({super.key});

  @override
  ConsumerState<AttendanceCheckinScreen> createState() => _AttendanceCheckinScreenState();
}

class _AttendanceCheckinScreenState extends ConsumerState<AttendanceCheckinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final isCheckedIn = state.activeRecord != null;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Page Header ─────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, color: AppColors.primaryTeal, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    l10n.attendanceScreenTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 2. Today's Shift Context Card ──────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, color: AppColors.primaryTeal, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.deptEmergency,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.shiftLongTiming,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.subtext(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.longPurpleBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '12h',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.longPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 3. Central GPS Geofence Radar Status ───────────────────────
              Center(
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      ),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCheckedIn
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.primaryTeal.withOpacity(0.1),
                          border: Border.all(
                            color: isCheckedIn
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.primaryTeal.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCheckedIn ? AppColors.success : AppColors.primaryTeal,
                              boxShadow: [
                                BoxShadow(
                                  color: (isCheckedIn ? AppColors.success : AppColors.primaryTeal).withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isCheckedIn ? Icons.verified_rounded : Icons.location_on_rounded,
                              size: 46,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.insideHospitalGeofence,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.gpsAccuracyGood,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── 4. Main Action Button ──────────────────────────────────────
              AppButton(
                text: isCheckedIn ? l10n.checkOutBtn : l10n.checkInBtn,
                icon: isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded,
                variant: isCheckedIn ? AppButtonVariant.danger : AppButtonVariant.primary,
                height: 52,
                isLoading: state.isProcessing,
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final user = ref.read(authProvider).user;
                  if (isCheckedIn) {
                    await notifier.checkOut();
                  } else {
                    await notifier.startCheckIn(
                      studentId: user?.id ?? 'std-1',
                      studentName: user?.fullName ?? 'طالب امتياز',
                      departmentName: 'قسم الطوارئ والعناية',
                    );
                  }
                },
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── 5. Attendance History for Current Month ───────────────────
              AppSectionHeader(
                title: l10n.attendanceHistoryTitle,
                subtitle: l10n.attendanceHistorySub,
              ),
              const SizedBox(height: 8),
              _buildAttendanceHistory(context, state.history, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory(BuildContext context, dynamic history, AppLocalizations l10n) {
    final records = [
      {'date': '17 Sep 2026', 'dept': l10n.deptEmergencyShort, 'in': '07:55 AM', 'out': '08:05 PM', 'status': l10n.statusCompleted},
      {'date': '15 Sep 2026', 'dept': l10n.deptEmergencyShort, 'in': '07:50 AM', 'out': '08:00 PM', 'status': l10n.statusCompleted},
      {'date': '14 Sep 2026', 'dept': l10n.deptInternalIcu, 'in': '07:58 AM', 'out': '08:02 PM', 'status': l10n.statusCompleted},
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        separatorBuilder: (_, __) => Divider(height: 10, color: AppColors.border(context)),
        itemBuilder: (context, index) {
          final r = records[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['dept']} — ${r['date']}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'In: ${r['in']} | Out: ${r['out']}',
                        style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r['status']!,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
