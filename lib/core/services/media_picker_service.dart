import 'package:flutter/foundation.dart';
import 'media_picker_web.dart' if (dart.library.io) 'media_picker_io.dart' as platform_picker;

export 'media_picker_web.dart' if (dart.library.io) 'media_picker_io.dart' show PickedImageData;

/// Unified Cross-Platform Media Picker Service.
/// Automatically utilizes Web Native HTML5 File Input on Web (zero plugin/channel failure)
/// and native platform ImagePicker on iOS & Android.
class MediaPickerService {
  MediaPickerService._();
  static final MediaPickerService instance = MediaPickerService._();

  Future<platform_picker.PickedImageData?> pickImage({bool fromCamera = false}) async {
    try {
      return await platform_picker.pickImagePlatform(fromCamera: fromCamera);
    } catch (e) {
      if (kDebugMode) print('[MediaPickerService] Error picking image: $e');
      rethrow;
    }
  }
}