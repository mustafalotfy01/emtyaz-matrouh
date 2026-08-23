import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_version_model.dart';
import '../repositories/app_versions_repository.dart';

final appVersionsRepositoryProvider = Provider<AppVersionsRepository>((ref) {
  return AppVersionsRepository();
});

@immutable
class AppVersionsState {
  final bool isLoading;
  final bool isSaving;
  final double uploadProgress;
  final int uploadedBytes;
  final int totalBytes;
  final String? uploadStatusText;
  final String? errorMessage;
  final List<AppVersionModel> versions;

  const AppVersionsState({
    this.isLoading = false,
    this.isSaving = false,
    this.uploadProgress = 0.0,
    this.uploadedBytes = 0,
    this.totalBytes = 0,
    this.uploadStatusText,
    this.errorMessage,
    this.versions = const [],
  });

  AppVersionsState copyWith({
    bool? isLoading,
    bool? isSaving,
    double? uploadProgress,
    int? uploadedBytes,
    int? totalBytes,
    String? uploadStatusText,
    String? errorMessage,
    List<AppVersionModel>? versions,
  }) {
    return AppVersionsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadStatusText: uploadStatusText,
      errorMessage: errorMessage,
      versions: versions ?? this.versions,
    );
  }

  AppVersionModel? get activeRelease {
    try {
      return versions.firstWhere((v) => v.isActive && v.platform == 'android');
    } catch (_) {
      return versions.isNotEmpty ? versions.first : null;
    }
  }
}

class AppVersionsNotifier extends StateNotifier<AppVersionsState> {
  final AppVersionsRepository _repo;

  AppVersionsNotifier(this._repo) : super(const AppVersionsState()) {
    loadVersions();
  }

  Future<void> loadVersions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repo.getAllVersions();
      state = state.copyWith(isLoading: false, versions: list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل قائمة الإصدارات: $e',
      );
    }
  }

  Future<bool> publishNewRelease({
    required String versionName,
    required int versionCode,
    required String apkUrl,
    String? releaseNotes,
    bool forceUpdate = false,
    int minimumSupportedVersion = 1,
    bool isActive = true,
    String? fileName,
    int? fileSize,
    Uint8List? apkBytes,
  }) async {
    state = state.copyWith(
      isSaving: true,
      uploadProgress: 0.0,
      uploadedBytes: 0,
      totalBytes: apkBytes?.length ?? fileSize ?? 0,
      uploadStatusText: (apkBytes != null && apkBytes.isNotEmpty)
          ? 'جاري إنشاء GitHub Release ورفع الحزمة...'
          : 'جاري تسجيل بيانات الإصدار...',
      errorMessage: null,
    );
    try {
      final directUrl = apkUrl.trim();

      // Check if duplicate version code exists in local state
      if (state.versions.any((v) => v.versionCode == versionCode)) {
        throw Exception('رقم البناء (#$versionCode) موجود بالفعل. يرجى استخدام رقم بناء أكبر.');
      }

      if (apkBytes != null && apkBytes.isNotEmpty) {
        // Publish via secure GitHub Releases Edge Function
        await _repo.publishViaGitHubRelease(
          versionName: versionName,
          versionCode: versionCode,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
          minimumSupportedVersion: minimumSupportedVersion,
          isActive: isActive,
          fileName: fileName,
          fileSize: fileSize ?? apkBytes.length,
          apkBytes: apkBytes,
          directDownloadUrl: directUrl.isNotEmpty ? directUrl : null,
          onProgress: (progress, sent, total) {
            final percent = (progress * 100).toStringAsFixed(0);
            final sentMb = (sent / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);

            state = state.copyWith(
              uploadProgress: progress,
              uploadedBytes: sent,
              totalBytes: total,
              uploadStatusText: progress >= 1.0
                  ? 'تم اكتمال الرفع بنجاح! جاري التوثيق...'
                  : 'جاري رفع الحزمة إلى GitHub Releases: $percent% ($sentMb / $totalMb MB)',
            );
          },
        );
      } else if (directUrl.isNotEmpty) {
        // Direct publish with URL
        state = state.copyWith(uploadStatusText: 'جاري توثيق بيانات الإصدار...');
        await _repo.publishRelease(
          versionName: versionName,
          versionCode: versionCode,
          apkDownloadUrl: directUrl,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
          minimumSupportedVersion: minimumSupportedVersion,
          isActive: isActive,
          fileName: fileName,
          fileSize: fileSize,
        );
      } else {
        throw Exception('يرجى اختيار ملف APK أو إدخال رابط التحميل المباشر للـ Release.');
      }

      await loadVersions();
      state = state.copyWith(
        isSaving: false,
        uploadProgress: 1.0,
        uploadStatusText: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        uploadProgress: 0.0,
        uploadStatusText: null,
        errorMessage: 'فشل نشر الإصدار: $e',
      );
      return false;
    }
  }

  Future<bool> toggleActiveStatus(String id, bool currentStatus) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repo.toggleActiveStatus(id, !currentStatus);
      await loadVersions();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'فشل تغيير حالة الإصدار: $e',
      );
      return false;
    }
  }

  Future<bool> deleteRelease(String id) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repo.deleteRelease(id);
      await loadVersions();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'فشل حذف الإصدار: $e',
      );
      return false;
    }
  }
}

final appVersionsProvider =
    StateNotifierProvider<AppVersionsNotifier, AppVersionsState>((ref) {
  final repo = ref.watch(appVersionsRepositoryProvider);
  return AppVersionsNotifier(repo);
});
