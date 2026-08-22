import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceCheckinScreen extends ConsumerStatefulWidget {
  const AttendanceCheckinScreen({super.key});

  @override
  ConsumerState<AttendanceCheckinScreen> createState() => _AttendanceCheckinScreenState();
}

class _AttendanceCheckinScreenState extends ConsumerState<AttendanceCheckinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(attendanceProvider.notifier).loadAttendanceHistory(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final isCheckedIn = state.activeRecord != null;
    final l10n = context.l10n;

    final accuracy = state.lastLocation?.accuracyMeters;
    final geofence = state.geofenceResult;

    String locationStatusText;
    Color statusColor;

    if (state.step == CheckInStep.gettingLocation) {
      locationStatusText = 'جاري تحديد الموقع...';
      statusColor = AppDesignTokens.primary;
    } else if (state.step == CheckInStep.refiningAccuracy || state.step == CheckInStep.poorAccuracyWarning) {
      locationStatusText = 'جاري تحسين دقة الموقع...';
      statusColor = AppDesignTokens.warning;
    } else if (geofence != null) {
      if (geofence.isInside) {
        locationStatusText = 'أنت داخل نطاق المستشفى (${geofence.distanceMeters.toStringAsFixed(0)}م)';
        statusColor = AppDesignTokens.success;
      } else {
        locationStatusText = 'أنت خارج نطاق المستشفى (${geofence.distanceMeters.toStringAsFixed(0)}م)';
        statusColor = AppDesignTokens.danger;
      }
    } else {
      locationStatusText = isCheckedIn ? 'تم التحقق من النطاق والمطابقة' : 'جاهز لتسجيل البصمة وتحديد الموقع';
      statusColor = isCheckedIn ? AppDesignTokens.success : AppDesignTokens.primary;
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            final user = ref.read(authProvider).user;
            if (user != null) {
              await notifier.loadAttendanceHistory(user.id);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, color: AppDesignTokens.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      l10n.attendanceScreenTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 2. Active Shift Context Card ───────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: AppDesignTokens.primary, size: 22),
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
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.shiftLongTiming,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.textSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppBadge(
                        label: 'طويل 12h',
                        variant: AppBadgeVariant.shiftLong,
                        size: AppBadgeSize.medium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── 3. Central GPS Geofence Verification Card ─────────────────
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  variant: isCheckedIn ? AppCardVariant.standard : AppCardVariant.accentTeal,
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCheckedIn ? AppDesignTokens.success : AppDesignTokens.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (isCheckedIn ? AppDesignTokens.success : AppDesignTokens.primary).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isCheckedIn ? Icons.verified_rounded : Icons.location_on_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              locationStatusText,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        if (accuracy != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'دقة الموقع: ${accuracy.toStringAsFixed(0)}م',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accuracy <= 35 ? AppDesignTokens.success : AppDesignTokens.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 4. Main Action Button ──────────────────────────────────────
                AppButton(
                  text: isCheckedIn ? l10n.checkOutBtn : l10n.checkInBtn,
                  icon: isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded,
                  variant: isCheckedIn ? AppButtonVariant.danger : AppButtonVariant.primary,
                  size: AppButtonSize.large,
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
                      color: AppDesignTokens.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                      border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: AppDesignTokens.danger, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── 5. Attendance History ──────────────────────────────────────
                AppSectionHeader(
                  title: l10n.attendanceHistoryTitle,
                  subtitle: l10n.attendanceHistorySub,
                ),
                const SizedBox(height: 8),
                _buildAttendanceHistoryList(context, state.history, state.isLoadingHistory),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistoryList(BuildContext context, List<AttendanceRecord> history, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: AppDesignTokens.primary),
        ),
      );
    }

    if (history.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: AppEmptyState(
          title: 'لا يوجد سجل حضور حتى الآن',
          subtitle: 'ستظهر هنا سجلات البصمة والحضور الفعلية بمجرد تسجيل حضورك في الشيفت.',
          icon: Icons.history_toggle_off_rounded,
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length,
        separatorBuilder: (context, index) => Divider(height: 10, color: AppDesignTokens.borderSubtle(context)),
        itemBuilder: (context, index) {
          final r = history[index];
          final dateStr = DateFormat('dd MMM yyyy', 'ar').format(r.checkInTime);
          final inTime = DateFormat('hh:mm a', 'ar').format(r.checkInTime);
          final outTime = r.checkOutTime != null ? DateFormat('hh:mm a', 'ar').format(r.checkOutTime!) : 'قيد التدريب';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  child: const Icon(Icons.verified_rounded, size: 18, color: AppDesignTokens.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.departmentName} — $dateStr',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'دخول: $inTime | خروج: $outTime',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
                AppBadge(
                  label: r.status.displayNameAr,
                  variant: r.status == AttendanceStatus.present
                      ? AppBadgeVariant.success
                      : (r.status == AttendanceStatus.late ? AppBadgeVariant.warning : AppBadgeVariant.neutral),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
