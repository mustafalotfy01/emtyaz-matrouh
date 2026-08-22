import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedImageData {
  final Uint8List bytes;
  final String extension;
  final String name;

  const PickedImageData({
    required this.bytes,
    required this.extension,
    required this.name,
  });
}

Future<PickedImageData?> pickImagePlatform({bool fromCamera = false}) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );

  if (pickedFile == null) return null;

  final bytes = await pickedFile.readAsBytes();
  final fileName = pickedFile.name;
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : 'jpg';

  return PickedImageData(
    bytes: bytes,
    extension: ext,
    name: fileName,
  );
}