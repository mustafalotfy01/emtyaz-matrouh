import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/user_profile_details_screen.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/community_service.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isSending = true);

    final success = await CommunityService.addComment(
      postId: widget.post.id,
      authorId: user.id,
      content: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _commentController.clear();
        ref.invalidate(postCommentsProvider(widget.post.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.post.id));
    final currentUser = ref.watch(authProvider).user;
    final isAuthor = currentUser?.id == widget.post.authorId;
    final isStaff = currentUser?.role != null && currentUser!.role.displayNameAr != 'طالب امتياز';

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a', 'ar').format(widget.post.createdAt);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('تفاصيل المشاركة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isStaff)
            IconButton(
              icon: Icon(
                widget.post.isGold ? Icons.star_rounded : Icons.star_outline_rounded,
                color: widget.post.isGold ? Colors.amber : AppDesignTokens.textSecondary(context),
              ),
              tooltip: widget.post.isGold ? 'إلغاء التمييز الذهبي' : 'تمييز كـ حالة ذهبية هامة 🌟',
              onPressed: () async {
                HapticFeedback.lightImpact();
                final newStatus = !widget.post.isGold;
                await ref.read(communityRepositoryProvider).toggleGoldPost(widget.post.id, newStatus);
                ref.invalidate(communityPostsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: newStatus ? Colors.amber.shade800 : AppDesignTokens.primary,
                      content: Text(newStatus
                          ? 'تم تمييز المنشور كـ حالة إكلينيكية ذهبية هامة جداً 🌟🥇'
                          : 'تم إلغاء التمييز الذهبي للمنشور'),
                    ),
                  );
                }
              },
            ),
          if (isAuthor || isStaff)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف المشاركة'),
                    content: const Text('هل أنت متأكد من رغبتك في حذف هذه المشاركة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await CommunityService.deletePost(widget.post.id);
                  if (context.mounted) {
                    ref.invalidate(communityPostsProvider);
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Card
                    Container(
                      decoration: widget.post.isGold
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.shade400, width: 1.8),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.12),
                                  AppDesignTokens.surface(context),
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                            )
                          : null,
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    UserProfileDetailsScreen.show(
                                      context,
                                      userId: widget.post.authorId,
                                      initialName: widget.post.authorName,
                                      initialAvatarUrl: widget.post.authorAvatarUrl,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppAvatar(name: widget.post.authorName, imageUrl: widget.post.authorAvatarUrl, size: AppAvatarSize.medium),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.post.authorName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppDesignTokens.textPrimary(context)),
                                          ),
                                          Text(
                                            dateStr,
                                            style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (widget.post.isGold)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'حالة ذهبية 🌟',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  AppBadge(
                                    label: widget.post.category.displayNameAr,
                                    variant: AppBadgeVariant.primary,
                                    size: AppBadgeSize.small,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.post.title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.post.content,
                              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppDesignTokens.textPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    AppSectionHeader(
                      title: 'التعليقات والمناقشات',
                      subtitle: 'تبادل الآراء مع زملائك والمشرفين',
                    ),
                    const SizedBox(height: 10),

                    // Comments List
                    commentsAsync.when(
                      data: (comments) {
                        if (comments.isEmpty) {
                          return const AppCard(
                            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            child: AppEmptyState(
                              title: 'لا توجد تعليقات بعد',
                              subtitle: 'كن أول من يشارك برأيه على هذا الموضوع.',
                              icon: Icons.chat_bubble_outline_rounded,
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = comments[index];
                            final commentDate = DateFormat('dd MMM, hh:mm a', 'ar').format(c.createdAt);
                            final isDoctorComment = c.authorRole == 'evaluating_doctor' || c.authorRole == 'super_admin';

                            return Container(
                              decoration: c.isRewarded
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.amber.shade500, width: 1.5),
                                    )
                                  : null,
                              child: AppCard(
                                padding: const EdgeInsets.all(12),
                                variant: c.isRewarded
                                    ? AppCardVariant.elevated
                                    : (isDoctorComment ? AppCardVariant.accentTeal : AppCardVariant.standard),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        UserProfileDetailsScreen.show(
                                          context,
                                          userId: c.authorId,
                                          initialName: c.authorName,
                                          initialAvatarUrl: c.authorAvatarUrl,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: AppAvatar(name: c.authorName, imageUrl: c.authorAvatarUrl, size: AppAvatarSize.small),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  UserProfileDetailsScreen.show(
                                                    context,
                                                    userId: c.authorId,
                                                    initialName: c.authorName,
                                                    initialAvatarUrl: c.authorAvatarUrl,
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      c.authorName,
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppDesignTokens.textPrimary(context)),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      c.roleBadgeLabel,
                                                      style: const TextStyle(fontSize: 10, color: AppDesignTokens.primary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                commentDate,
                                                style: TextStyle(fontSize: 10, color: AppDesignTokens.textSecondary(context)),
                                              ),
                                            ],
                                          ),
                                          if (c.isRewarded)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4, bottom: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.amber.shade400, width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    c.rewardTitle ?? 'إجابة متميزة ومكافأة من المشرف 🏆 (+10 نقاط)',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            c.displayContent,
                                            style: TextStyle(fontSize: 12.5, color: AppDesignTokens.textPrimary(context), height: 1.3),
                                          ),
                                          if (isStaff && !c.isRewarded && !c.isStaff)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                icon: const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
                                                label: const Text(
                                                  'منح مكافأة تميز (+10 نقاط) 🏆',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                                ),
                                                onPressed: () async {
                                                  HapticFeedback.lightImpact();
                                                  await ref.read(communityRepositoryProvider).rewardComment(
                                                    commentId: c.id,
                                                    currentContent: c.content,
                                                  );
                                                  ref.invalidate(postCommentsProvider(widget.post.id));
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        backgroundColor: AppDesignTokens.success,
                                                        content: Text('تم منح مكافأة التميز للتعليق بنجاح 🏆✨'),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppDesignTokens.primary))),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Comment Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface(context),
                border: Border(top: BorderSide(color: AppDesignTokens.border(context))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: _commentController,
                      hintText: 'أضف تعليقك...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignTokens.primary))
                        : const Icon(Icons.send_rounded, color: AppDesignTokens.primary),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
