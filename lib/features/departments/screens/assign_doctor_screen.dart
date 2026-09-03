import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../models/department.dart';
import '../providers/department_provider.dart';

class AssignDoctorScreen extends ConsumerStatefulWidget {
  final Department department;
  final DepartmentSupervisorInfo? existingSupervisor;

  const AssignDoctorScreen({
    super.key,
    required this.department,
    this.existingSupervisor,
  });

  @override
  ConsumerState<AssignDoctorScreen> createState() => _AssignDoctorScreenState();
}

class _AssignDoctorScreenState extends ConsumerState<AssignDoctorScreen> {
  String? _selectedDoctorId;
  String _searchQuery = '';
  late TextEditingController _maleCapController;
  late TextEditingController _femaleCapController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDoctorId = widget.existingSupervisor?.doctorId;
    _maleCapController = TextEditingController(
      text: (widget.existingSupervisor?.maleCapacity ?? widget.department.maleCapacity).toString(),
    );
    _femaleCapController = TextEditingController(
      text: (widget.existingSupervisor?.femaleCapacity ?? widget.department.femaleCapacity).toString(),
    );
  }

  @override
  void dispose() {
    _maleCapController.dispose();
    _femaleCapController.dispose();
    super.dispose();
  }

  Future<void> _submitAssignment() async {
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الطبيب المشرف أولاً'),
          backgroundColor: AppDesignTokens.warning,
        ),
      );
      return;
    }

    final maleCap = int.tryParse(_maleCapController.text.trim()) ?? 0;
    final femaleCap = int.tryParse(_femaleCapController.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    try {
      await ref.read(departmentsProvider.notifier).assignDoctor(
            departmentId: widget.department.id,
            doctorId: _selectedDoctorId!,
            maleCapacity: maleCap,
            femaleCapacity: femaleCap,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعيين واعتماد الطبيب المشرف بنجاح'),
            backgroundColor: AppDesignTokens.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppDesignTokens.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(evaluatingDoctorsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text('تكليف طبيب مشرف — ${widget.department.nameAr}'),
      ),
      body: SafeArea(
        child: doctorsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingSkeleton(itemCount: 4, height: 80),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorState(
              title: 'تعذر تحميل قائمة الأطباء المقيّمين',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.refresh(evaluatingDoctorsProvider),
            ),
          ),
          data: (doctors) {
            final filteredDoctors = doctors.where((doc) {
              if (_searchQuery.isEmpty) return true;
              return doc.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  doc.universityCode.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Department Context Banner
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    variant: AppCardVariant.accentTeal,
                    child: Row(
                      children: [
                        const Icon(Icons.domain_rounded, color: AppDesignTokens.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.department.nameAr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'السعة الحالية: ${widget.department.maleCapacity} ذكور | ${widget.department.femaleCapacity} إناث',
                                style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search Field
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم الطبيب أو كود المشرف...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: AppDesignTokens.surface(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        borderSide: BorderSide(color: AppDesignTokens.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        borderSide: BorderSide(color: AppDesignTokens.border(context)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'اختر الطبيب المسؤول عن القسم:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (filteredDoctors.isEmpty)
                    const AppEmptyState(
                      title: 'لا يوجد أطباء مقيّمين مطابقين',
                      message: 'تأكد من تسجيل الأطباء برتبة "evaluating_doctor" في النظام.',
                      icon: Icons.person_search_rounded,
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredDoctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = filteredDoctors[index];
                        final isSelected = _selectedDoctorId == doc.id;

                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            setState(() => _selectedDoctorId = doc.id);
                          },
                          variant: isSelected ? AppCardVariant.elevated : AppCardVariant.standard,
                          child: Row(
                            children: [
                              AppAvatar(
                                name: doc.fullName,
                                imageUrl: doc.avatarUrl,
                                size: AppAvatarSize.medium,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.fullName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppDesignTokens.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'كود: ${doc.universityCode} • الهاتف: ${doc.phoneNumber}',
                                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppDesignTokens.primary, size: 24)
                              else
                                const Icon(Icons.radio_button_unchecked_rounded, color: AppDesignTokens.slateMuted, size: 22),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  // Open Supervision Capacity Information
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.all_inclusive_rounded, color: AppDesignTokens.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حصة الإشراف: مفتوحة بالكامل',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppDesignTokens.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'يمكن تكليف الطبيب المشرف بمتابعة وتقييم أي عدد من الطلاب والجروبات في هذا القسم بدون حد أقصى.',
                                style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  AppButton(
                    text: 'تأكيد التكليف والاعتماد',
                    icon: Icons.verified_user_rounded,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSaving,
                    onPressed: _submitAssignment,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
