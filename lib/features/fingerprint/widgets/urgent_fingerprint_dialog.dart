import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/hospital_location_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/platform_service.dart';
import '../../../core/services/vibration_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/distance_calculator.dart';
import '../models/fingerprint_request.dart';
import '../providers/fingerprint_provider.dart';

/// Shows an urgent bottom-sheet dialog prompting the student to confirm their fingerprint.
void showUrgentFingerprintDialog(
  BuildContext context,
  WidgetRef ref,
  FingerprintRequest req,
) {
  HapticFeedback.heavyImpact();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => Container(
        decoration: BoxDecoration(
          color: AppDesignTokens.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignTokens.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded, size: 42, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 12),
            const Text(
              'تأكيد التواجد الفوري بمستشفى مطروح العام',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    'المهلة المتبقية: ${req.remainingTimeFormatted} (حد أقصى 5 دقائق)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'طلب رسمي صادر من: ${req.senderName}\nيرجى تأكيد البصمة الحيوية وإرسال الموقع الجغرافي من داخل نطاق المستشفى لإثبات الحضور الفعلي.',
              style: TextStyle(fontSize: 12.5, color: AppDesignTokens.textSecondary(context), height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (req.notes != null && req.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.border(context)),
                ),
                child: Text(
                  req.notes!,
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (isSubmitting)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFDC2626)),
                  SizedBox(height: 10),
                  Text('جارٍ التحقق البيومتري وتأكيد النطاق الجغرافي للمستشفى...', style: TextStyle(fontSize: 12)),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
                      label: const Text('بصم الآن 📱📍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        // 1. Check 5-minute timeout expiration
                        if (req.isExpired) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppDesignTokens.danger,
                                duration: Duration(seconds: 4),
                                content: Text('عذراً، انتهت مهلة الـ 5 دقائق المحددة لتأكيد البصمة الفورية ⏰'),
                              ),
                            );
                          }
                          return;
                        }

                        setModalState(() => isSubmitting = true);
                        try {
                          // 2. Biometric verification
                          final bioRes = await PlatformService.biometric.authenticate(
                            reason: 'تأكيد بصمة التواجد الفوري بمستشفى مطروح العام',
                          );

                          if (!bioRes.success && !PlatformService.isWeb) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppDesignTokens.danger,
                                  content: Text('فشل التحقق البيومتري من البصمة ❌'),
                                ),
                              );
                            }
                            return;
                          }

                          // 3. Fetch GPS coordinates
                          final loc = await LocationService.getCurrentLocation();
                          final userLat = loc.latitude ?? 0.0;
                          final userLon = loc.longitude ?? 0.0;

                          // 4. Verify Hospital Geofence dynamically from HospitalConfig
                          await ref.read(hospitalConfigProvider.notifier).loadConfig();
                          final hospitalCfg = ref.read(hospitalConfigProvider);
                          final hospitalLat = hospitalCfg.latitude;
                          final hospitalLon = hospitalCfg.longitude;
                          final allowedRadiusMeters = hospitalCfg.radiusMeters;
                          final hospitalName = hospitalCfg.hospitalName;
                          final isInsideHospital = (loc.latitude != null && loc.longitude != null) &&
                              DistanceCalculator.isWithinZone(
                                userLat: userLat,
                                userLon: userLon,
                                zoneLat: hospitalLat,
                                zoneLon: hospitalLon,
                                radiusMeters: allowedRadiusMeters,
                              );

                          final distanceMeters = (loc.latitude != null && loc.longitude != null)
                              ? DistanceCalculator.calculateDistanceMeters(
                                  userLat,
                                  userLon,
                                  hospitalLat,
                                  hospitalLon,
                                )
                              : 999999.0;

                          if (!isInsideHospital) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              final distText = distanceMeters >= 1000
                                  ? '${(distanceMeters / 1000).toStringAsFixed(1)} كم'
                                  : '${distanceMeters.round()} متر';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppDesignTokens.danger,
                                  duration: const Duration(seconds: 5),
                                  content: Text(
                                    'أنت خارج نطاق $hospitalName ($distText بعيداً، النطاق المسموح: ${allowedRadiusMeters.round()} متر). يجب التواجد داخل المستشفى لإثبات البصمة الفورية 📍🏥',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          // 5. Confirm in Supabase
                          await ref.read(fingerprintRequestsProvider.notifier).confirmFingerprint(
                            requestId: req.id,
                            latitude: loc.latitude,
                            longitude: loc.longitude,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppDesignTokens.success,
                                content: Text('تم تأكيد التواجد داخل مستشفى مطروح العام بالبصمة الحيوية بنجاح ✅📍'),
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppDesignTokens.danger,
                                content: Text('حدث خطأ أثناء تأكيد البصمة: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}
