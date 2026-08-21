import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/firebase_options.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_messaging_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/providers/auth_provider.dart';

class FcmDebugScreen extends ConsumerStatefulWidget {
  const FcmDebugScreen({super.key});

  @override
  ConsumerState<FcmDebugScreen> createState() => _FcmDebugScreenState();
}

class _FcmDebugScreenState extends ConsumerState<FcmDebugScreen> {
  bool _isLoading = false;
  String? _statusLog;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    await FirebaseMessagingService.instance.ensureFirebaseCoreInitialized();
    await FirebaseMessagingService.instance.ensureMessagingInitialized();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fcm = FirebaseMessagingService.instance;
    final push = PushNotificationService.instance;
    final permStatus = push.getPermissionStatus();
    final isIosSafari = push.isIosSafariNonStandalone();
    final hasVapid = DefaultFirebaseOptions.webVapidKey.isNotEmpty;
    final hasToken = fcm.currentToken != null && fcm.currentToken!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text(
          '🛠️ تشخيص إشعارات FCM والتسجيل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Status Overview Card
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined, color: AppColors.primaryTeal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'حالة تكامل Firebase Cloud Messaging:',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildStatusRow(
                  context,
                  'Firebase initialized:',
                  fcm.isFirebaseCoreInitialized ? 'PASS ✓' : 'FAIL ✕',
                  fcm.isFirebaseCoreInitialized ? AppColors.success : AppColors.danger,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'Notification permission:',
                  permStatus == PushPermissionStatus.granted
                      ? 'GRANTED ✓'
                      : (permStatus == PushPermissionStatus.denied ? 'DENIED ✕' : 'PROMPT / WAITING'),
                  permStatus == PushPermissionStatus.granted ? AppColors.success : AppColors.warning,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'Firebase Messaging initialized:',
                  fcm.isMessagingInitialized ? 'PASS ✓' : 'FAIL ✕',
                  fcm.isMessagingInitialized ? AppColors.success : AppColors.danger,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'Service Worker:',
                  kIsWeb ? 'REGISTERED ✓ (/firebase-messaging-sw.js)' : 'NATIVE PLATFORM',
                  AppColors.success,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'VAPID key:',
                  hasVapid ? 'CONFIGURED ✓' : 'MISSING ✕',
                  hasVapid ? AppColors.success : AppColors.danger,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'FCM Token:',
                  hasToken ? 'GENERATED ✓' : 'FAILED / NOT GENERATED',
                  hasToken ? AppColors.success : AppColors.warning,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'Token Storage:',
                  hasToken ? 'SYNCED TO SUPABASE ✓' : 'NOT SYNCED',
                  hasToken ? AppColors.success : AppColors.warning,
                ),
                const Divider(height: 10),

                _buildStatusRow(
                  context,
                  'Platform / Browser:',
                  kIsWeb
                      ? (isIosSafari ? 'iPhone Safari (متصفح عادي)' : 'Web / PWA Standalone')
                      : defaultTargetPlatform.name,
                  AppColors.primaryTeal,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. FCM Token Card (Masked with copy button)
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_outlined, color: AppColors.primaryTeal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'رمز التسجيل (FCM Registration Token):',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    if (hasToken)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: AppColors.primaryTeal),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fcm.maskedToken,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Exact Error Log Section
          if (fcm.lastError != null) ...[
            const SizedBox(height: 16),
            CustomCard(
              borderColor: AppColors.danger.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Exact FCM Error Details:',
                        style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.muted(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      fcm.lastError!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 4. Action Buttons
          CustomButton(
            text: 'تفعيل الصلاحيات واستخراج رمز FCM Token 🔔',
            icon: Icons.notification_add,
            isLoading: _isLoading,
            color: AppColors.primaryTeal,
            onPressed: () async {
              setState(() => _isLoading = true);
              await fcm.ensureFirebaseCoreInitialized();
              await fcm.ensureMessagingInitialized();
              await fcm.requestPermission();
              final token = await fcm.retrieveToken();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _statusLog = token != null
                      ? 'تم توليد الرمز بنجاح ومزامنته مع السيرفر ✅'
                      : 'لم يتم توليد الرمز، يرجى مراجعة تفاصيل الخطأ بالأعلى';
                });
              }
            },
          ),

          const SizedBox(height: 10),

          CustomButton(
            text: 'إرسال إشعار تجريبي للجهاز 🚀',
            icon: Icons.send_to_mobile,
            color: AppColors.accentCyan,
            onPressed: () async {
              final auth = ref.read(authProvider);
              final user = auth.user;
              final fcmToken = fcm.currentToken;

              if (kDebugMode) {
                print('──────────────────────────────────────────────────');
                print('[TEST_PUSH] BUTTON_CLICKED');
                print('[TEST_PUSH] AUTHENTICATED: ${user != null}');
                print('[TEST_PUSH] USER_ID: ${user?.id ?? "none"}');
                print('[TEST_PUSH] USER_ROLE: ${user?.role.name ?? "none"}');
                print('[TEST_PUSH] FCM_TOKEN_EXISTS: ${fcmToken != null && fcmToken.isNotEmpty}');
                print('[TEST_PUSH] TOKEN_LENGTH: ${fcmToken?.length ?? 0}');
                print('[TEST_PUSH] CALLING_PUSH_SERVICE');
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  duration: Duration(milliseconds: 800),
                  content: Text('جاري إرسال الإشعار...'),
                ),
              );

              try {
                final success = await push.showBrowserNotification(
                  title: 'امتياز مطروح (FCM Test)',
                  body: 'تم اختبار نظام التنبيهات الفورية بنجاح على هذا الجهاز! 🎉',
                  route: '/notifications',
                );

                if (kDebugMode) {
                  print('[TEST_PUSH] PUSH_SERVICE_RETURNED: $success');
                }

                if (mounted) {
                  if (success) {
                    if (kDebugMode) print('[TEST_PUSH] SUCCESS');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('تم إرسال الإشعار بنجاح ✅'),
                      ),
                    );
                    setState(() {
                      _statusLog = 'تم إرسال الإشعار التجريبي للجهاز بنجاح ✅';
                    });
                  } else {
                    final perm = push.getPermissionStatus();
                    final reason = perm != PushPermissionStatus.granted
                        ? 'إذن الإشعارات غير مفعل ($perm)'
                        : 'فشل استدعاء ServiceWorker/Notification API';
                    if (kDebugMode) print('[TEST_PUSH] ERROR: $reason');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.danger,
                        content: Text('فشل إرسال الإشعار: $reason ✕'),
                      ),
                    );
                    setState(() {
                      _statusLog = 'فشل إرسال الإشعار: $reason ✕';
                    });
                  }
                }
              } catch (e, st) {
                if (kDebugMode) {
                  print('[TEST_PUSH_ERROR] $e');
                  print(st);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text('فشل إرسال الإشعار: $e ✕'),
                    ),
                  );
                  setState(() {
                    _statusLog = 'فشل إرسال الإشعار: $e ✕';
                  });
                }
              }
            },
          ),

          if (_statusLog != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Text(
                _statusLog!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryTeal),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String title, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
