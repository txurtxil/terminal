import 'package:flutter/services.dart';

class NativePaths {
  static const _channel = MethodChannel('linux_container/native_paths');

  static Future<String> getNativeLibraryDir() async {
    final dir = await _channel.invokeMethod<String>('getNativeLibraryDir');
    if (dir == null) {
      throw StateError('No se pudo obtener nativeLibraryDir');
    }
    return dir;
  }
}
