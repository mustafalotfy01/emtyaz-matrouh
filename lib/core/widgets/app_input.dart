import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

class AppInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final bool isReadOnly;
  final bool isEnabled;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  const AppInput({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.isReadOnly = false,
    this.isEnabled = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.onTap,
    this.focusNode,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);

    Widget? effectiveSuffixIcon = widget.suffixIcon;
    if (widget.isPassword) {
      effectiveSuffixIcon = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppDesignTokens.textMuted(context),
          size: 18,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscureText,
          readOnly: widget.isReadOnly,
          enabled: widget.isEnabled,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          validator: widget.validator,
          onTap: widget.onTap,
          style: TextStyle(
            fontSize: 14,
            color: AppDesignTokens.textPrimary(context),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? widget.hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppDesignTokens.textMuted(context),
              fontWeight: FontWeight.normal,
            ),
            helperText: widget.helperText,
            helperStyle: TextStyle(
              fontSize: 11,
              color: AppDesignTokens.textMuted(context),
            ),
            errorText: widget.errorText,
            errorStyle: const TextStyle(
              fontSize: 11,
              color: AppDesignTokens.danger,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: widget.prefixIcon,
            suffixIcon: effectiveSuffixIcon,
            filled: true,
            fillColor: widget.isEnabled
                ? (isDark ? AppDesignTokens.surfaceMutedDark : AppDesignTokens.surfaceMutedLight)
                : (isDark ? AppDesignTokens.bgDark : AppDesignTokens.borderSubtleLight),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              borderSide: BorderSide(color: AppDesignTokens.border(context), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              borderSide: BorderSide(color: AppDesignTokens.border(context), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              borderSide: const BorderSide(color: AppDesignTokens.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              borderSide: const BorderSide(color: AppDesignTokens.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              borderSide: const BorderSide(color: AppDesignTokens.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
