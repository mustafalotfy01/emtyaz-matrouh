import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

class AppLoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;
  final ShapeBorder? shape;
  final int? itemCount;

  const AppLoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
    this.shape,
    this.itemCount,
  });

  const AppLoadingSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        itemCount = null,
        shape = const CircleBorder();

  @override
  State<AppLoadingSkeleton> createState() => _AppLoadingSkeletonState();
}

class _AppLoadingSkeletonState extends State<AppLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);
    final baseColor = isDark
        ? AppDesignTokens.surfaceElevatedDark
        : AppDesignTokens.surfaceMutedLight;

    Widget buildSingleItem() {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: ShapeDecoration(
                color: baseColor,
                shape: widget.shape ??
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.borderRadius ?? AppDesignTokens.radiusSm,
                      ),
                    ),
              ),
            ),
          );
        },
      );
    }

    if (widget.itemCount != null && widget.itemCount! > 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          widget.itemCount!,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == widget.itemCount! - 1 ? 0 : 12.0),
            child: buildSingleItem(),
          ),
        ),
      );
    }

    return buildSingleItem();
  }
}
