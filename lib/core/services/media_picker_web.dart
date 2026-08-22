import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

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
  final completer = Completer<PickedImageData?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/jpeg,image/png,image/webp,image/jpg,image/heic';
  if (fromCamera) {
    input.setAttribute('capture', 'user');
  }

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();
    reader.onLoadEnd.listen((e) {
      try {
        final result = reader.result;
        if (result != null) {
          final jsBuffer = result as JSArrayBuffer;
          final bytes = jsBuffer.toDart.asUint8List();
          final fileName = file.name;
          final ext = fileName.contains('.')
              ? fileName.split('.').last.toLowerCase()
              : 'jpg';
          if (!completer.isCompleted) {
            completer.complete(PickedImageData(
              bytes: bytes,
              extension: ext,
              name: fileName,
            ));
          }
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      } catch (err) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}