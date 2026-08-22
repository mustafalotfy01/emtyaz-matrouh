import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/handover_model.dart';
import '../services/handover_service.dart';

final handoversProvider = FutureProvider<List<HandoverModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  final isStaff = user?.role != null && user!.role.displayNameAr != 'طالب امتياز';
  return await HandoverService.fetchHandovers(
    userId: user?.id ?? '',
    isStaff: isStaff,
  );
});
