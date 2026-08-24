import 'package:flutter/material.dart';
import '../../features/auth/models/user_profile.dart';
import '../../features/profile/screens/user_profile_details_screen.dart';
import '../models/user_presence_model.dart';
import '../theme/app_design_tokens.dart';

class ClickableUserIdentity extends StatelessWidget {
  final String userId;
  final String fullName;
  final String? subtitle;
  final String? studentCode;
  final String? avatarUrl;
  final UserRole? role;
  final UserPresenceModel? presence;
  final double avatarRadius;
  final TextStyle? nameStyle;
  final bool showOnlineDot;
  final VoidCallback? onTapOverride;

  const ClickableUserIdentity({
    super.key,
    required this.userId,
    required this.fullName,
    this.subtitle,
    this.studentCode,
    this.avatarUrl,
    this.role,
    this.presence,
    this.avatarRadius = 20,
    this.nameStyle,
    this.showOnlineDot = true,
    this.onTapOverride,
  });

  void _handleTap(BuildContext context) {
    if (onTapOverride != null) {
      onTapOverride!();
      return;
    }

    UserProfileDetailsScreen.show(
      context,
      userId: userId,
      initialName: fullName,
      initialAvatarUrl: avatarUrl,
      initialRole: role,
      initialCode: studentCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEffectivelyOnline = presence?.isEffectivelyOnline ?? false;

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with Online Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppDesignTokens.primary.withOpacity(0.12),
                  backgroundImage: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.trim().isEmpty)
                      ? Text(
                          fullName.isNotEmpty ? fullName.substring(0, 1) : 'U',
                          style: TextStyle(
                            fontSize: avatarRadius * 0.9,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.primary,
                          ),
                        )
                      : null,
                ),
                if (showOnlineDot && isEffectivelyOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: avatarRadius * 0.55,
                      height: avatarRadius * 0.55,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981), // Emerald online dot
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // Name + Subtitle / Code
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: nameStyle ??
                        TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null || studentCode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle ?? (studentCode != null ? 'كود: $studentCode' : ''),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignTokens.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
