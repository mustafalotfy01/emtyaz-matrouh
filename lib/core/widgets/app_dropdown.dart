import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? customWidget;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.customWidget,
  });
}

class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;
  final String? errorText;
  final bool isEnabled;

  const AppDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.errorText,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark ? AppDesignTokens.surfaceMutedDark : AppDesignTokens.surfaceMutedLight)
                : (isDark ? AppDesignTokens.bgDark : AppDesignTokens.borderSubtleLight),
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
            border: Border.all(
              color: errorText != null
                  ? AppDesignTokens.danger
                  : AppDesignTokens.border(context),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hintText != null
                  ? Text(
                      hintText!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.textMuted(context),
                      ),
                    )
                  : null,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppDesignTokens.textSecondary(context),
                size: 20,
              ),
              dropdownColor: AppDesignTokens.surface(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item.value,
                  child: item.customWidget ??
                      Row(
                        children: [
                          if (item.icon != null) ...[
                            Icon(item.icon, size: 16, color: AppDesignTokens.primary),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: item.value == value ? FontWeight.bold : FontWeight.normal,
                              color: AppDesignTokens.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                );
              }).toList(),
              onChanged: isEnabled ? onChanged : null,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 11,
              color: AppDesignTokens.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
