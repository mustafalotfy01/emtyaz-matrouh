import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../attendance/screens/location_picker_screen.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _universityCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gpaController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  StudentGroup _studentGroup = StudentGroup.groupA;
  String _gender = 'male';
  final String _maritalStatus = 'أعزب/عزباء';
  final int _childrenCount = 0;
  bool _isMatrouhResident = true;
  double? _selectedHomeLat;
  double? _selectedHomeLng;
  bool _isLocatingGps = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _universityCodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gpaController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _selectedHomeLat ?? 31.3543,
          initialLng: _selectedHomeLng ?? 27.2373,
          initialRadius: 100.0,
          initialHospitalName: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : 'محل سكن الطالب بمطروح',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedHomeLat = result.latitude;
        _selectedHomeLng = result.longitude;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = result.hospitalName;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد موقع السكن: (${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)})',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final loc = await LocationService.getCurrentLocation(skipAccuracyCheck: true);
      if (loc.isSuccess && loc.latitude != null && loc.longitude != null && mounted) {
        setState(() {
          _selectedHomeLat = loc.latitude!;
          _selectedHomeLng = loc.longitude!;
          if (_addressController.text.trim().isEmpty) {
            _addressController.text = 'موقعي الحالي المسجل بـ GPS';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديد الموقع بدقة: (${loc.latitude!.toStringAsFixed(4)}, ${loc.longitude!.toStringAsFixed(4)})',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر جلب موقع GPS: ${loc.errorMessageAr}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final newProfile = UserProfile(
      id: '',
      email: _emailController.text.trim(),
      fullName: _fullNameController.text.trim(),
      universityCode: _universityCodeController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      gpa: double.tryParse(_gpaController.text.trim()),
      gender: _gender,
      maritalStatus: _maritalStatus,
      childrenCount: _childrenCount,
      isMatrouhResident: _isMatrouhResident,
      emergencyContact: _emergencyContactController.text.trim(),
      residenceAddress: _addressController.text.trim().isEmpty
          ? 'مرسى مطروح'
          : _addressController.text.trim(),
      latitude: _selectedHomeLat ?? 31.3520,
      longitude: _selectedHomeLng ?? 27.2410,
      role: UserRole.student,
      studentGroup: StudentGroup.groupA,
    );

    final success = await ref.read(authProvider.notifier).register(
          newProfile,
          _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 28),
              const SizedBox(width: 10),
              Text(
                'تم استلام طلب التسجيل بنجاح',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_top, color: AppColors.warning, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'حالة الطلب: قيد المراجعة والتدقيق',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بانتظار مراجعة واعتماد منسق الامتياز (Leader)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• الكود الجامعي: ${_universityCodeController.text.trim()}\n'
                '• البريد المسجل: ${_emailController.text.trim()}\n\n'
                '📌 لا يلزم تأكيد البريد الإلكتروني. سيتم تفعيل حسابك مباشرة فور اعتماد المنسق لبياناتك.',
                style: TextStyle(fontSize: 12, color: AppColors.subtext(context), height: 1.5),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              child: const Text('الانتقال لشاشة تسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      final errorMsg = ref.read(authProvider).error ?? 'فشل إنشاء الحساب، يرجى التحقق من البيانات';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 28),
              SizedBox(width: 10),
              Text('تعذر إنشاء الحساب', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(errorMsg, style: TextStyle(fontSize: 13, color: AppColors.text(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          'تسجيل طالب جديد',
          style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'البيانات الأكاديمية والأساسية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gender selector placed first so capacity is clear
                      Row(
                        children: [
                          Text('النوع / الجنس: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context))),
                          Radio<String>(
                            value: 'male',
                            groupValue: _gender,
                            activeColor: AppColors.primaryTeal,
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                          Text('ذكر (حد أقصى 20)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text(context))),
                          const SizedBox(width: 10),
                          Radio<String>(
                            value: 'female',
                            groupValue: _gender,
                            activeColor: AppColors.primaryTeal,
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                          Text('أنثى (حد أقصى 35)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text(context))),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Student Group Selection with Live Capacity Limits (20 Males / 35 Females)
                      Text(
                        'المجموعة المحددة لتوزيع الروستر (السعة المتبقية):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                      ),
                      const SizedBox(height: 8),

                      Builder(
                        builder: (context) {
                          final capacityAsync = ref.watch(groupCapacityProvider);
                          final cap = capacityAsync.value ?? const GroupCapacityInfo();

                          final remainingA = cap.getRemaining(StudentGroup.groupA, _gender);
                          final remainingB = cap.getRemaining(StudentGroup.groupB, _gender);
                          final maxCount = cap.getMax(_gender);

                          final isAAvailable = remainingA > 0;
                          final isBAvailable = remainingB > 0;

                          return Column(
                            children: [
                              InkWell(
                                onTap: isAAvailable ? () => setState(() => _studentGroup = StudentGroup.groupA) : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _studentGroup == StudentGroup.groupA
                                        ? AppColors.primaryTeal.withValues(alpha: 0.15)
                                        : AppColors.card(context),
                                    border: Border.all(
                                      color: _studentGroup == StudentGroup.groupA
                                          ? AppColors.primaryTeal
                                          : AppColors.border(context),
                                      width: _studentGroup == StudentGroup.groupA ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<StudentGroup>(
                                        value: StudentGroup.groupA,
                                        groupValue: _studentGroup,
                                        activeColor: AppColors.primaryTeal,
                                        onChanged: isAAvailable ? (v) => setState(() => _studentGroup = v!) : null,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'المجموعة A (الأيام 1 إلى 16)',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                            ),
                                            Text(
                                              'تتيح اختيار 12 Option A و 12 Option B من الأيام 1-16',
                                              style: TextStyle(fontSize: 10, color: AppColors.subtext(context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isAAvailable ? AppColors.successLight.withValues(alpha: 0.2) : AppColors.dangerLight.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isAAvailable ? 'متبقي: $remainingA / $maxCount' : 'اكتملت السعة ❌',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAAvailable ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              InkWell(
                                onTap: isBAvailable ? () => setState(() => _studentGroup = StudentGroup.groupB) : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _studentGroup == StudentGroup.groupB
                                        ? AppColors.primaryTeal.withValues(alpha: 0.15)
                                        : AppColors.card(context),
                                    border: Border.all(
                                      color: _studentGroup == StudentGroup.groupB
                                          ? AppColors.primaryTeal
                                          : AppColors.border(context),
                                      width: _studentGroup == StudentGroup.groupB ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<StudentGroup>(
                                        value: StudentGroup.groupB,
                                        groupValue: _studentGroup,
                                        activeColor: AppColors.primaryTeal,
                                        onChanged: isBAvailable ? (v) => setState(() => _studentGroup = v!) : null,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'المجموعة B (الأيام 17 إلى نهاية الشهر)',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                            ),
                                            Text(
                                              'تتيح اختيار 12 Option A و 12 Option B من الأيام 17-31',
                                              style: TextStyle(fontSize: 10, color: AppColors.subtext(context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isBAvailable ? AppColors.successLight.withValues(alpha: 0.2) : AppColors.dangerLight.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isBAvailable ? 'متبقي: $remainingB / $maxCount' : 'اكتملت السعة ❌',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBAvailable ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _fullNameController,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: const InputDecoration(
                          labelText: 'الاسم الرباعي بالطريقة الرسمية',
                          prefixIcon: Icon(Icons.person, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _universityCodeController,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: const InputDecoration(
                          labelText: 'الكود الجامعي (University Code)',
                          prefixIcon: Icon(Icons.badge, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال الكود الجامعي' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: AppColors.text(context)),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'البريد غير صحيح' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: AppColors.text(context)),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف المحمول',
                          prefixIcon: Icon(Icons.phone, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || v.length < 10) ? 'رقم الهاتف غير صحيح' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _gpaController,
                        style: TextStyle(color: AppColors.text(context)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'المعدل التراكمي (GPA) *',
                          hintText: 'مثال: 3.85',
                          prefixIcon: Icon(Icons.school_outlined, color: AppColors.primaryTeal),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'المعدل التراكمي (GPA) مطلوب';
                          }
                          final gpaVal = double.tryParse(v.trim());
                          if (gpaVal == null || gpaVal < 0.0 || gpaVal > 4.0) {
                            return 'يرجى إدخال GPA صحيح بين 0.00 و 4.00';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور الحصينة',
                          prefixIcon: Icon(Icons.lock, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                CustomCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الحالة الاجتماعية والسكن للطوارئ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Residence switch
                      SwitchListTile(
                        title: Text('هل أنت من أبناء محافظة مطروح؟', style: TextStyle(color: AppColors.text(context), fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(_isMatrouhResident ? 'مقيم بالمحافظة' : 'مغترب (سكن طلابي)', style: TextStyle(color: AppColors.subtext(context), fontSize: 11)),
                        value: _isMatrouhResident,
                        activeThumbColor: AppColors.primaryTeal,
                        onChanged: (v) => setState(() => _isMatrouhResident = v),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emergencyContactController,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: const InputDecoration(
                          labelText: 'رقم الطوارئ وصفتها (مثال: 01099887766 - الأب)',
                          prefixIcon: Icon(Icons.contact_phone, color: AppColors.primaryTeal),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال رقم الطوارئ' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _addressController,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: const InputDecoration(
                          labelText: 'عنوان السكن التفصيلي (مثال: مرسى مطروح - شارع علم الروم)',
                          prefixIcon: Icon(Icons.home, color: AppColors.primaryTeal),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Location on Map Picker Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.map, color: AppColors.primaryTeal, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'تحديد الموقع الجغرافي للمنزل / السكن',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                ),
                                const Spacer(),
                                if (_selectedHomeLat != null)
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedHomeLat != null)
                              Text(
                                '📍 الإحداثيات المحددة: ${_selectedHomeLat!.toStringAsFixed(5)}, ${_selectedHomeLng!.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal, fontWeight: FontWeight.bold),
                              )
                            else
                              Text(
                                'لتسهيل تحديد نطاق الوصول في حالات الطوارئ ونداءات الاستدعاء، حدد موقع سكنك:',
                                style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickLocationOnMap,
                                    icon: const Icon(Icons.pin_drop, size: 16),
                                    label: const Text('اختيار من الخريطة 🗺️', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryTeal,
                                      side: const BorderSide(color: AppColors.primaryTeal),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isLocatingGps ? null : _useCurrentGpsLocation,
                                    icon: _isLocatingGps
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                                          )
                                        : const Icon(Icons.my_location, size: 16),
                                    label: const Text('موقعي الحالي GPS', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryTeal,
                                      side: const BorderSide(color: AppColors.primaryTeal),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                CustomButton(
                  text: 'تسجيل الحساب وتفعيل البروفايل',
                  icon: Icons.check_circle_outline,
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
