import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/firebase_messaging_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class SystemHealthProbeResult {
  final String serviceName;
  final String status;
  final bool isPass;
  final int? latencyMs;
  final String? details;

  const SystemHealthProbeResult({
    required this.serviceName,
    required this.status,
    required this.isPass,
    this.latencyMs,
    this.details,
  });
}

class FcmDebugScreen extends ConsumerStatefulWidget {
  const FcmDebugScreen({super.key});

  @override
  ConsumerState<FcmDebugScreen> createState() => _FcmDebugScreenState();
}

class _FcmDebugScreenState extends ConsumerState<FcmDebugScreen> {
  bool _isLoading = false;
  final List<SystemHealthProbeResult> _probeResults = [];

  @override
  void initState() {
    super.initState();
    _runComprehensiveDiagnostics();
  }

  Future<void> _runComprehensiveDiagnostics() async {
    setState(() => _isLoading = true);
    _probeResults.clear();

    final fcm = FirebaseMessagingService.instance;
    await fcm.ensureFirebaseCoreInitialized();
    await fcm.ensureMessagingInitialized();

    // 1. Firebase Probe
    _probeResults.add(
      SystemHealthProbeResult(
        serviceName: 'Firebase Cloud Messaging (FCM)',
        status: fcm.isFirebaseCoreInitialized ? 'PASS' : 'FAIL',
        isPass: fcm.isFirebaseCoreInitialized,
        details: fcm.currentToken != null ? 'Token Active' : 'No Token',
      ),
    );

    // 2. Supabase Auth & Session Probe
    final client = Supabase.instance.client;
    final hasSession = client.auth.currentSession != null;
    _probeResults.add(
      SystemHealthProbeResult(
        serviceName: 'Supabase Auth & RLS',
        status: hasSession ? 'PASS' : 'UNAUTHENTICATED',
        isPass: hasSession,
        details: hasSession ? 'JWT Valid' : 'Session Expired',
      ),
    );

    // 3. PostgreSQL Database Probe with Real Latency
    final sw = Stopwatch()..start();
    try {
      await client.from('profiles').select('id').limit(1);
      sw.stop();
      _probeResults.add(
        SystemHealthProbeResult(
          serviceName: 'PostgreSQL Database',
          status: 'PASS',
          isPass: true,
          latencyMs: sw.elapsedMilliseconds,
          details: '${sw.elapsedMilliseconds} ms latency',
        ),
      );
    } catch (e) {
      sw.stop();
      _probeResults.add(
        SystemHealthProbeResult(
          serviceName: 'PostgreSQL Database',
          status: 'FAIL',
          isPass: false,
          details: e.toString(),
        ),
      );
    }

    // 4. Supabase Storage Probe
    try {
      final buckets = await client.storage.listBuckets();
      _probeResults.add(
        SystemHealthProbeResult(
          serviceName: 'Supabase Storage Buckets',
          status: 'PASS',
          isPass: true,
          details: '${buckets.length} Active Buckets',
        ),
      );
    } catch (e) {
      _probeResults.add(
        SystemHealthProbeResult(
          serviceName: 'Supabase Storage Buckets',
          status: 'FAIL',
          isPass: false,
          details: 'Permission / Bucket query failed',
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fcm = FirebaseMessagingService.instance;
    final push = PushNotificationService.instance;
    final hasToken = fcm.currentToken != null && fcm.currentToken!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text(
          'تشخيص وفحص سلامة النظام (System Health)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _runComprehensiveDiagnostics,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. System Probes Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: AppDesignTokens.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'حالة خدمات البنية التحتية والسيرفر:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading && _probeResults.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppDesignTokens.primary)))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _probeResults.length,
                    separatorBuilder: (_, __) => Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                    itemBuilder: (ctx, i) {
                      final p = _probeResults[i];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.serviceName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppDesignTokens.textPrimary(context))),
                              if (p.details != null)
                                Text(p.details!, style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                            ],
                          ),
                          AppBadge(
                            label: p.latencyMs != null ? '${p.status} (${p.latencyMs}ms)' : p.status,
                            variant: p.isPass ? AppBadgeVariant.success : AppBadgeVariant.danger,
                            size: AppBadgeSize.small,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. FCM Token Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, color: AppDesignTokens.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'رمز التسجيل (FCM Token):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    if (hasToken)
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppDesignTokens.primary),
                        tooltip: 'نسخ الرمز كاملاً',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: fcm.currentToken!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ رمز FCM للحافظة 📋')),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  child: Text(
                    fcm.maskedToken,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Actions
          AppButton(
            text: 'إعادة فحص سلامة جميع الخدمات 🔄',
            icon: Icons.sync_rounded,
            isLoading: _isLoading,
            onPressed: _runComprehensiveDiagnostics,
          ),

          const SizedBox(height: 10),

          AppButton(
            text: 'إرسال إشعار تجريبي للجهاز 🚀',
            icon: Icons.send_to_mobile_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              try {
                final success = await push.showBrowserNotification(
                  title: 'MANU (System Diagnostic)',
                  body: 'تم اختبار قنوات البث والإشعارات الفورية بنجاح ✅',
                  route: '/notifications',
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: success ? AppDesignTokens.success : AppDesignTokens.danger,
                      content: Text(success ? 'تم إرسال الإشعار بنجاح ✅' : 'فشل إرسال الإشعار ❌'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppDesignTokens.danger, content: Text('خطأ: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
