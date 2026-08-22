import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/group_preferences_service.dart';

class GroupSelectionScreen extends ConsumerStatefulWidget {
  const GroupSelectionScreen({super.key});

  @override
  ConsumerState<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends ConsumerState<GroupSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';

  List<UserProfile> _availableStudents = [];
  final List<String> _selectedStudentIds = []; // Ordered by priority (index 0 = Priority 1)
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).user;
    final userId = user?.id ?? '';

    setState(() => _isLoading = true);

    final peers = await GroupPreferencesService.fetchAvailablePeers(currentUserId: userId);
    final savedPrefs = await GroupPreferencesService.fetchStudentPreferences(studentId: userId);

    if (mounted) {
      setState(() {
        _availableStudents = peers;
        _selectedStudentIds.clear();
        for (final p in savedPrefs) {
          if (peers.any((s) => s.id == p.preferredStudentId)) {
            _selectedStudentIds.add(p.preferredStudentId);
          }
        }
        if (savedPrefs.isNotEmpty && savedPrefs.first.notes != null) {
          _notesController.text = savedPrefs.first.notes!;
        }
        _isSubmitted = savedPrefs.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  void _toggleStudent(UserProfile student) {
    HapticFeedback.lightImpact();
    final isSelected = _selectedStudentIds.contains(student.id);

    setState(() {
      if (isSelected) {
        _selectedStudentIds.remove(student.id);
      } else {
        if (_selectedStudentIds.length >= 11) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يمكنك اختيار ما يصل إلى 11 زميلاً كحد أقصى.'),
              backgroundColor: AppDesignTokens.warning,
            ),
          );
          return;
        }
        _selectedStudentIds.add(student.id);
      }
    });
  }

  void _movePriority(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedStudentIds.removeAt(oldIndex);
      _selectedStudentIds.insert(newIndex, item);
    });
  }

  Future<void> _submitPreferences() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isSaving = true);

    final success = await GroupPreferencesService.submitPreferences(
      studentId: user.id,
      preferredStudentIds: _selectedStudentIds,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isSubmitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم إرسال تفضيلات المجموعة لليدر بنجاح ✓' : 'تعذر حفظ التفضيلات. حاول مجدداً.'),
          backgroundColor: success ? AppDesignTokens.success : AppDesignTokens.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppDesignTokens.bg(context),
        appBar: AppBar(
          title: const Text('تفضيلات المجموعة'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary)),
      );
    }

    final filtered = _availableStudents.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.fullName.toLowerCase().contains(_searchQuery) ||
          s.universityCode.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('تفضيلات المجموعة (Group Preferences)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Clear Policy & Advisory Banner ──────────────────────────
              AppCard(
                variant: AppCardVariant.accentTeal,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: AppDesignTokens.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تفضيلات توزيع المجموعات السريرية',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppDesignTokens.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'هذه التفضيلات تساعد الليدر في توزيع المجموعات، ولا تضمن وجود جميع الأسماء معًا.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.textSecondary(context),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'المسار المعتمد: تفضيلات الطالب ← اقتراح الليدر ← مراجعة واعتماد الإدارة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Selected Preferences Rank List ─────────────────────────
              if (_selectedStudentIds.isNotEmpty) ...[
                AppSectionHeader(
                  title: 'الزملاء المختارون بترتيب الأولوية',
                  subtitle: 'يمكنك إعادة الترتيب بالسحب والإفلات حسب الأولوية',
                  actionText: '${_selectedStudentIds.length} / 11 زميل',
                ),
                const SizedBox(height: 8),

                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedStudentIds.length,
                  onReorder: _movePriority,
                  itemBuilder: (context, index) {
                    final studentId = _selectedStudentIds[index];
                    final student = _availableStudents.firstWhere(
                      (s) => s.id == studentId,
                      orElse: () => UserProfile(
                        id: studentId,
                        email: '',
                        fullName: 'زميل امتياز',
                        universityCode: '',
                        phoneNumber: '',
                        gender: 'male',
                        maritalStatus: 'single',
                        childrenCount: 0,
                        isMatrouhResident: true,
                        emergencyContact: '',
                        residenceAddress: '',
                        role: UserRole.student,
                      ),
                    );

                    return Container(
                      key: ValueKey(studentId),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppDesignTokens.primary,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            AppAvatar(name: student.fullName, imageUrl: student.avatarUrl, size: AppAvatarSize.small),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.fullName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                                  ),
                                  if (student.universityCode.isNotEmpty)
                                    Text(
                                      student.universityCode,
                                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppDesignTokens.danger),
                              onPressed: () => _toggleStudent(student),
                            ),
                            const Icon(Icons.drag_handle_rounded, size: 20, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── 3. Notes Input ────────────────────────────────────────────
              AppInput(
                controller: _notesController,
                label: 'ملاحظات إضافية لليدر (اختياري)',
                hintText: 'مثال: أسباب تتعلق بالسكن المشترك أو وسائل النقل لمطروح...',
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // ── 4. Peer Search & Selection List ───────────────────────────
              AppSectionHeader(
                title: 'قائمة زملاء الدفعة المتاحين',
                subtitle: 'اختر الزملاء لإضافتهم لقائمة تفضيلاتك',
              ),
              const SizedBox(height: 8),

              AppInput(
                controller: _searchController,
                hintText: 'ابحث بالاسم أو الكود الجامعي...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),

              if (filtered.isEmpty)
                const AppCard(
                  padding: EdgeInsets.all(20),
                  child: AppEmptyState(
                    title: 'لا توجد نتائج مطابقة',
                    subtitle: 'تأكد من كتابة الاسم أو الكود بشكل صحيح.',
                    icon: Icons.person_search_rounded,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final isSelected = _selectedStudentIds.contains(s.id);
                    final priorityIndex = _selectedStudentIds.indexOf(s.id);

                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      variant: isSelected ? AppCardVariant.accentTeal : AppCardVariant.standard,
                      onTap: () => _toggleStudent(s),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: AppDesignTokens.primary,
                            onChanged: (_) => _toggleStudent(s),
                          ),
                          AppAvatar(name: s.fullName, imageUrl: s.avatarUrl, size: AppAvatarSize.small),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.fullName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                                ),
                                Text(
                                  '${s.universityCode} • ${s.gender == 'male' ? "ذكر" : "أنثى"}',
                                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            AppBadge(
                              label: 'أولوية #${priorityIndex + 1}',
                              variant: AppBadgeVariant.success,
                              size: AppBadgeSize.small,
                            ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // ── 5. Submit Button ──────────────────────────────────────────
              AppButton(
                text: _isSaving
                    ? 'جاري إرسال التفضيلات...'
                    : (_isSubmitted
                        ? 'تحديث تفضيلات المجموعة (${_selectedStudentIds.length} زملاء)'
                        : 'إرسال تفضيلات المجموعة لليدر (${_selectedStudentIds.length} زملاء)'),
                icon: Icons.send_rounded,
                size: AppButtonSize.large,
                isLoading: _isSaving,
                onPressed: _selectedStudentIds.isNotEmpty ? _submitPreferences : null,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
