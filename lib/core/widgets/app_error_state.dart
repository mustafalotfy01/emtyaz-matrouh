import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import 'app_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String? errorMessage;
  final String? message;
  final VoidCallback? onRetry;
  final String retryText;

  const AppErrorState({
    super.key,
    this.title = 'حدث خطأ أثناء تحميل البيانات',
    this.errorMessage,
    this.message,
    this.onRetry,
    this.retryText = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignTokens.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppDesignTokens.danger,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),
            if ((errorMessage ?? message) != null) ...[
              const SizedBox(height: 6),
              Text(
                (errorMessage ?? message)!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.danger,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                text: retryText,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
