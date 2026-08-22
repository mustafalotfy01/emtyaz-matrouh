import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_design_tokens.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outline,
  danger,
  ghost,
  whitePill,
}

enum AppButtonSize {
  small,
  medium,
  large,
}

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.lightImpact();
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);

    // Height & font size based on size preset
    double defaultHeight;
    double fontSize;
    double iconSize;
    EdgeInsetsGeometry defaultPadding;

    switch (widget.size) {
      case AppButtonSize.small:
        defaultHeight = 36.0;
        fontSize = 12.5;
        iconSize = 15.0;
        defaultPadding = const EdgeInsets.symmetric(horizontal: 12.0);
        break;
      case AppButtonSize.medium:
        defaultHeight = 46.0;
        fontSize = 14.0;
        iconSize = 18.0;
        defaultPadding = const EdgeInsets.symmetric(horizontal: 16.0);
        break;
      case AppButtonSize.large:
        defaultHeight = 52.0;
        fontSize = 15.5;
        iconSize = 20.0;
        defaultPadding = const EdgeInsets.symmetric(horizontal: 20.0);
        break;
    }

    final effectiveHeight = widget.height ?? defaultHeight;
    final effectivePadding = widget.padding ?? defaultPadding;
    final effectiveRadius = widget.borderRadius ?? AppDesignTokens.radiusMd;

    // Color resolution
    Color bgColor;
    Color textColor;
    Border? border;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bgColor = AppDesignTokens.primary;
        textColor = Colors.white;
        border = null;
        break;
      case AppButtonVariant.secondary:
        bgColor = isDark ? AppDesignTokens.surfaceElevatedDark : AppDesignTokens.navyDark;
        textColor = Colors.white;
        border = null;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = AppDesignTokens.primary;
        border = Border.all(color: AppDesignTokens.primary, width: 1.5);
        break;
      case AppButtonVariant.danger:
        bgColor = AppDesignTokens.danger;
        textColor = Colors.white;
        border = null;
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = AppDesignTokens.textPrimary(context);
        border = null;
        break;
      case AppButtonVariant.whitePill:
        bgColor = Colors.white;
        textColor = AppDesignTokens.navyDark;
        border = Border.all(color: AppDesignTokens.borderLight, width: 1);
        break;
    }

    final bool isDisabled = widget.onPressed == null || widget.isLoading;
    if (isDisabled) {
      bgColor = bgColor.withOpacity(0.5);
      textColor = textColor.withOpacity(0.7);
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          width: widget.width,
          height: effectiveHeight,
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: border,
            boxShadow: widget.variant == AppButtonVariant.primary && !isDisabled
                ? [
                    BoxShadow(
                      color: AppDesignTokens.primary.withOpacity(0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CupertinoActivityIndicator(
                      color: textColor,
                      radius: iconSize / 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: textColor, size: iconSize),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.text,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
