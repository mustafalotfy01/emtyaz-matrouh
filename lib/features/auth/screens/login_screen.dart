import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_logo.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.student;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        context.go('/main');
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login(
          _codeController.text.trim(),
          _passwordController.text.trim(),
          expectedRole: _selectedRole,
        );

    if (success && mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = context.l10n;

    // Auto-redirect if user session is loaded
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null && mounted) {
        context.go('/main');
      }
    });

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: AppLogo(
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    l10n.isArabic
                        ? 'تسجيل الدخول لمنظومة امتياز التمريض السريري'
                        : 'Clinical Nursing Internship Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppDesignTokens.textSecondary(context),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Role Selector
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isArabic ? 'تحديد الدور الوظيفي:' : 'Select Login Role:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildRoleChip(context, UserRole.student, l10n.isArabic ? 'طالب امتياز' : 'Intern Student'),
                            _buildRoleChip(context, UserRole.leader, l10n.isArabic ? 'ليدر' : 'Leader'),
                            _buildRoleChip(context, UserRole.evaluatingDoctor, l10n.isArabic ? 'دكتور مشرف' : 'Supervisor Doctor'),
                            _buildRoleChip(context, UserRole.superAdmin, l10n.isArabic ? 'الإدارة العليا' : 'Senior Management'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login Form Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Identifier Input
                        AppInput(
                          label: _selectedRole == UserRole.student
                              ? (l10n.isArabic ? 'الكود الجامعي أو البريد الإلكتروني' : 'University Code or Email')
                              : (l10n.isArabic ? 'البريد الإلكتروني المسجل' : 'Registered Email Address'),
                          controller: _codeController,
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                        ),

                        const SizedBox(height: 14),

                        // Password Input
                        AppInput(
                          label: l10n.isArabic ? 'كلمة المرور' : 'Password',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        ),

                        const SizedBox(height: 8),

                        // Forgot Password Link
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: _codeController.text.contains('@')
                                        ? _codeController.text.trim()
                                        : null,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              l10n.isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppDesignTokens.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        if (authState.error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.danger.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                              border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.error!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppDesignTokens.danger,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Submit Button
                        AppButton(
                          text: '${l10n.isArabic ? "تسجيل الدخول كـ" : "Login as"} ${l10n.isArabic ? _selectedRole.displayNameAr : _selectedRole.displayNameEn}',
                          icon: Icons.login_rounded,
                          isLoading: authState.isLoading,
                          onPressed: _handleLogin,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.isArabic ? 'ليس لديك حساب طالب؟ ' : "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.textSecondary(context),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppDesignTokens.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, UserRole role, String title) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _codeController.clear();
          _passwordController.clear();
        });
      },
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surfaceMuted(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
