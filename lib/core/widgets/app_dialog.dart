import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;
  final IconData? icon;

  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmText = 'تأكيد',
    this.cancelText = 'إلغاء',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
    this.icon,
  });

  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDesignTokens.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        side: BorderSide(color: AppDesignTokens.border(context), width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDestructive ? AppDesignTokens.danger : AppDesignTokens.primary)
                    .withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive ? AppDesignTokens.danger : AppDesignTokens.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDestructive ? AppDesignTokens.danger : AppDesignTokens.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null)
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.textSecondary(context),
                height: 1.4,
              ),
            ),
          if (content != null) ...[
            if (message != null) const SizedBox(height: 12),
            content!,
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: cancelText,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onCancel ?? () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                text: confirmText,
                variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                size: AppButtonSize.small,
                isLoading: isLoading,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
