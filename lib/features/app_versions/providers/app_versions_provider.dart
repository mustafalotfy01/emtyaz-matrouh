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
  final String? errorMessage;
  final List<AppVersionModel> versions;

  const AppVersionsState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.versions = const [],
  });

  AppVersionsState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    List<AppVersionModel>? versions,
  }) {
    return AppVersionsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
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
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      String finalUrl = apkUrl.trim();

      // If APK binary is provided, upload it to storage first
      if (apkBytes != null && apkBytes.isNotEmpty) {
        final actualFileName = (fileName != null && fileName.isNotEmpty)
            ? fileName
            : 'app-release.apk';

        finalUrl = await _repo.uploadApkBinary(
          versionName: versionName,
          fileName: actualFileName,
          fileBytes: apkBytes,
        );
      }

      if (finalUrl.isEmpty) {
        throw Exception('رابط تحميل APK أو الملف مطلوب لنشر الإصدار');
      }

      await _repo.publishRelease(
        versionName: versionName,
        versionCode: versionCode,
        apkDownloadUrl: finalUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
        minimumSupportedVersion: minimumSupportedVersion,
        isActive: isActive,
        fileName: fileName,
        fileSize: fileSize ?? apkBytes?.length,
      );

      await loadVersions();
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
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

  Future<bool> deleteRelease(String id, {String? storagePath}) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repo.deleteRelease(id, storagePath: storagePath);
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
