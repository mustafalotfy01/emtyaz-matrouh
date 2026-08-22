import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String? subtitle;
  final String? description;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.subtitle,
    this.description,
    this.icon = Icons.folder_open_rounded,
    this.actionText,
    this.onAction,
    this.iconSize = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveText = message ?? subtitle ?? description;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: AppDesignTokens.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),
            if (effectiveText != null) ...[
              const SizedBox(height: 6),
              Text(
                effectiveText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppDesignTokens.textSecondary(context),
                  height: 1.4,
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 18),
              AppButton(
                text: actionText!,
                onPressed: onAction,
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
