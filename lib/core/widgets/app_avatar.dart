import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

enum AppAvatarSize {
  small,   // 32px
  medium,  // 44px
  large,   // 64px
  xlarge,  // 88px
}

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final AppAvatarSize size;
  final VoidCallback? onEditTap;
  final bool isOnline;
  final bool showOnlineIndicator;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppAvatarSize.medium,
    this.onEditTap,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.borderColor,
  });

  double get _dimension {
    switch (size) {
      case AppAvatarSize.small:
        return 32.0;
      case AppAvatarSize.medium:
        return 44.0;
      case AppAvatarSize.large:
        return 64.0;
      case AppAvatarSize.xlarge:
        return 88.0;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppAvatarSize.small:
        return 12.0;
      case AppAvatarSize.medium:
        return 16.0;
      case AppAvatarSize.large:
        return 22.0;
      case AppAvatarSize.xlarge:
        return 30.0;
    }
  }

  String get _initials {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return 'ط';
    final parts = cleanName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return parts[0][0];
  }

  Color _deterministicBgColor(String text) {
    const palette = [
      Color(0xFF0A7B83),
      Color(0xFF0E3B43),
      Color(0xFF0284C7),
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF2563EB),
    ];
    if (text.isEmpty) return palette[0];
    final hash = text.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }

  Widget _buildImageWidget(String url, double dim, Color fallbackBg) {
    final clean = url.trim();
    if (clean.isEmpty) return _buildFallback(dim, fallbackBg);

    // 1. Base64 Data URI (e.g. data:image/png;base64,...) or raw base64
    if (clean.startsWith('data:image') || clean.startsWith('data:')) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Str = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(base64Str.trim());
        return ClipRRect(
          borderRadius: BorderRadius.circular(dim / 2),
          child: Image.memory(
            bytes,
            width: dim,
            height: dim,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(dim, fallbackBg),
          ),
        );
      } catch (_) {
        return _buildFallback(dim, fallbackBg);
      }
    }

    // 2. Local File
    if (clean.startsWith('/') || clean.startsWith('file://')) {
      try {
        final path = clean.replaceFirst('file://', '');
        return ClipRRect(
          borderRadius: BorderRadius.circular(dim / 2),
          child: Image.file(
            File(path),
            width: dim,
            height: dim,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(dim, fallbackBg),
          ),
        );
      } catch (_) {
        return _buildFallback(dim, fallbackBg);
      }
    }

    // 3. Network URL (HTTP/HTTPS)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(dim / 2),
        child: Image.network(
          clean,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(dim, fallbackBg),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: dim,
              height: dim,
              color: AppDesignTokens.surfaceMuted(context),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignTokens.primary),
                ),
              ),
            );
          },
        ),
      );
    }

    // 4. Raw base64 string fallback
    if (clean.length > 100 && !clean.contains(' ')) {
      try {
        final bytes = base64Decode(clean);
        return ClipRRect(
          borderRadius: BorderRadius.circular(dim / 2),
          child: Image.memory(
            bytes,
            width: dim,
            height: dim,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(dim, fallbackBg),
          ),
        );
      } catch (_) {}
    }

    return _buildFallback(dim, fallbackBg);
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimension;
    final fallbackBg = _deterministicBgColor(name);

    final Widget avatarCore = imageUrl != null && imageUrl!.isNotEmpty
        ? _buildImageWidget(imageUrl!, dim, fallbackBg)
        : _buildFallback(dim, fallbackBg);

    final decoratedAvatar = Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? AppDesignTokens.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: avatarCore,
    );

    if (onEditTap == null && !showOnlineIndicator) {
      return decoratedAvatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        decoratedAvatar,
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dim * 0.28,
              height: dim * 0.28,
              decoration: BoxDecoration(
                color: isOnline ? AppDesignTokens.success : AppDesignTokens.textMuted(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppDesignTokens.surface(context),
                  width: 2,
                ),
              ),
            ),
          ),
        if (onEditTap != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppDesignTokens.surface(context),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(double dim, Color bgColor) {
    return Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: bgColor,
            fontSize: _fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
