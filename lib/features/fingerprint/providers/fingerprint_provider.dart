import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/fingerprint_request.dart';
import '../repositories/fingerprint_repository.dart';

final fingerprintRepositoryProvider = Provider<FingerprintRepository>((ref) {
  return FingerprintRepository();
});

class FingerprintRequestsNotifier
    extends StateNotifier<AsyncValue<List<FingerprintRequest>>> {
  final FingerprintRepository _repository;
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;

  FingerprintRequestsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRequests();
    _subscribeRealtime();
    // Poll every 10 seconds to guarantee instant responsiveness across all networks
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => loadRequests());
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isInitialized) return;
    try {
      _subscription = SupabaseService.client
          .channel('public:confirmation_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'confirmation_requests',
            callback: (payload) {
              loadRequests();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRequests() async {
    try {
      final list = await _repository.fetchRequests();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendImmediateRequest({
    required String audienceType,
    String? targetStudentId,
    String? title,
    String? notes,
  }) async {
    await _repository.sendImmediateRequest(
      audienceType: audienceType,
      targetStudentId: targetStudentId,
      title: title,
      notes: notes,
    );
    await loadRequests();
  }

  Future<void> confirmFingerprint({
    required String requestId,
    double? latitude,
    double? longitude,
  }) async {
    await _repository.confirmFingerprint(
      requestId: requestId,
      latitude: latitude,
      longitude: longitude,
    );
    await loadRequests();
  }
}

final fingerprintRequestsProvider = StateNotifierProvider<
    FingerprintRequestsNotifier, AsyncValue<List<FingerprintRequest>>>((ref) {
  final repo = ref.watch(fingerprintRepositoryProvider);
  return FingerprintRequestsNotifier(repo);
});

final studentActiveFingerprintRequestProvider = Provider<FingerprintRequest?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null || user.role != UserRole.student) return null;

  final requestsAsync = ref.watch(fingerprintRequestsProvider);
  return requestsAsync.maybeWhen(
    data: (requests) {
      final now = DateTime.now();
      for (final req in requests) {
        if (!req.isPending) continue;
        // Check if created within last 25 minutes
        final diff = now.difference(req.sentAt);
        if (diff.inMinutes > 25) continue;

        // Check audience
        if (req.audienceType == 'ALL') return req;
        if (req.audienceType == 'SPECIFIC_STUDENT' && req.targetStudentId == user.id) return req;
        if (req.audienceType.startsWith('DEPARTMENT:')) return req;
        if (req.audienceType.startsWith('SHIFT:') || req.audienceType == 'CURRENT_SHIFT') return req;
      }
      return null;
    },
    orElse: () => null,
  );
});

