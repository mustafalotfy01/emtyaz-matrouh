import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import 'create_post_sheet.dart';
import 'post_detail_screen.dart';

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  String _selectedFilter = 'all'; // 'all', 'gold', 'caseStudy', 'announcement', 'educational'

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          backgroundColor: AppDesignTokens.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: const Text('مشاركة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const CreatePostSheet(),
            );
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(communityPostsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: AppDesignTokens.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'مجتمع الامتياز (Community)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Filter Chips ───────────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'الكل 🌐'),
                      const SizedBox(width: 8),
                      _buildFilterChip('gold', 'حالات ذهبية هامة 🌟🥇'),
                      const SizedBox(width: 8),
                      _buildFilterChip('caseStudy', 'دراسة حالة 🩺'),
                      const SizedBox(width: 8),
                      _buildFilterChip('announcement', 'إعلانات رسمية 📢'),
                      const SizedBox(width: 8),
                      _buildFilterChip('educational', 'معلومات سريرية 💡'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Posts Stream ──────────────────────────────────────────────
                postsAsync.when(
                  data: (posts) {
                    final filteredPosts = posts.where((p) {
                      if (_selectedFilter == 'gold') return p.isGold;
                      if (_selectedFilter == 'caseStudy') return p.category == PostCategory.caseStudy;
                      if (_selectedFilter == 'announcement') return p.category == PostCategory.announcement;
                      if (_selectedFilter == 'educational') return p.category == PostCategory.educational;
                      return true;
                    }).toList();

                    if (posts.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد مشاركات حتى الآن',
                          subtitle: 'كن أول من يبدأ المناقشة ويشارك خبراته وحالاته السريرية مع زملائه.',
                          icon: Icons.forum_outlined,
                        ),
                      );
                    }

                    if (filteredPosts.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد مشاركات في هذا التصنيف',
                          subtitle: 'اختر تصنيفاً آخر أو اضغط على الكل لرؤية جميع الموضوعات.',
                          icon: Icons.filter_alt_off_rounded,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredPosts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        final dateStr = DateFormat('dd MMM yyyy', 'ar').format(post.createdAt);

                        return Container(
                          decoration: post.isGold
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.shade400, width: 1.6),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.withOpacity(0.08),
                                      AppDesignTokens.surface(context),
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                )
                              : null,
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(post: post),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AppAvatar(name: post.authorName, imageUrl: post.authorAvatarUrl, size: AppAvatarSize.small),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.authorName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                                          ),
                                          Text(
                                            dateStr,
                                            style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (post.isGold)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade600,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.stars_rounded, size: 13, color: Colors.white),
                                            SizedBox(width: 3),
                                            Text(
                                              'حالة ذهبية 🌟',
                                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      AppBadge(
                                        label: post.category.displayNameAr,
                                        variant: AppBadgeVariant.primary,
                                        size: AppBadgeSize.small,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  post.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppDesignTokens.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.content,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppDesignTokens.textSecondary(context),
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.mode_comment_outlined, size: 15, color: AppDesignTokens.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${post.commentsCount} تعليق',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppDesignTokens.primary),
                    ),
                  ),
                  error: (_, __) => const AppCard(
                    padding: EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'لا توجد مشاركات حتى الآن',
                      subtitle: 'تعذر الاتصال بالخادم. اسحب لأسفل للتحديث.',
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
