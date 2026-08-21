import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/roster_entry.dart';
import '../providers/roster_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ShiftRequestModal extends ConsumerStatefulWidget {
  final DateTime initialDate;

  const ShiftRequestModal({super.key, required this.initialDate});

  @override
  ConsumerState<ShiftRequestModal> createState() => _ShiftRequestModalState();
}

class _ShiftRequestModalState extends ConsumerState<ShiftRequestModal> {
  late DateTime _selectedDate;
  ShiftType _selectedShift = ShiftType.long;
  String _selectedDeptId = 'a0000001-0000-0000-0000-000000000001';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsProvider);
    final currentUser = ref.watch(authProvider).user;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'طلب شيفت جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 16),

            // Date picker field
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              leading: const Icon(Icons.calendar_today, color: AppColors.primaryTeal),
              title: const Text('التاريخ المطلوب'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),

            const SizedBox(height: 16),

            // Department Selection
            DropdownButtonFormField<String>(
              value: _selectedDeptId,
              decoration: const InputDecoration(
                labelText: 'القسم المطلوب',
                prefixIcon: Icon(Icons.local_hospital, color: AppColors.primaryTeal),
              ),
              items: depts.map((d) {
                return DropdownMenuItem(
                  value: d.id,
                  child: Text(d.nameAr),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDeptId = val);
              },
            ),

            const SizedBox(height: 16),

            // Shift Type Selection
            const Text(
              'نوع الشيفت:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),

            Column(
              children: ShiftType.values.where((s) => s != ShiftType.absence).map((st) {
                return RadioListTile<ShiftType>(
                  value: st,
                  groupValue: _selectedShift,
                  title: Text(st.displayNameAr, style: const TextStyle(fontSize: 14)),
                  activeColor: AppColors.primaryTeal,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedShift = val);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            CustomButton(
              text: 'إرسال طلب الشيفت',
              icon: Icons.send,
              onPressed: () {
                final dept = depts.firstWhere((d) => d.id == _selectedDeptId);
                final newEntry = RosterEntry(
                  id: 'ros-${DateTime.now().millisecondsSinceEpoch}',
                  studentId: currentUser?.id ?? 'student-001',
                  studentName: currentUser?.fullName ?? 'أحمد محمود',
                  departmentId: dept.id,
                  departmentName: dept.nameAr,
                  shiftDate: _selectedDate,
                  shiftType: _selectedShift,
                  status: ShiftStatus.pending,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تقديم طلب الشيفت بنجاح وقيد مراجعة المنسق')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
