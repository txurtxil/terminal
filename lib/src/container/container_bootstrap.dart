import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'native_paths.dart';

class ContainerPaths {
  final String prootPath;
  final String rootfsPath;
  ContainerPaths(this.prootPath, this.rootfsPath);
}

class _ExtractParams {
  final Uint8List rootfsBytes;
  final String containerDirPath;
  _ExtractParams(this.rootfsBytes, this.containerDirPath);
}

class ContainerBootstrap {
  static const _rootfsAsset = 'assets/container/rootfs.tar.xz';
  static const _markerFileName = '.bootstrap_complete';

  Future<void> _ensureMountPoints(Directory rootfsDir) async {
    for (final name in ['system', 'apex']) {
      final dir = Directory('${rootfsDir.path}/$name');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  Future<ContainerPaths> ensureExtracted({
    void Function(String status, double progress)? onProgress,
  }) async {
    final nativeLibDir = await NativePaths.getNativeLibraryDir();
    final prootPath = '$nativeLibDir/libproot.so';

    final supportDir = await getApplicationSupportDirectory();
    final containerDir = Directory('${supportDir.path}/container');
    final rootfsDir = Directory('${containerDir.path}/rootfs');
    final markerFile = File('${containerDir.path}/$_markerFileName');

    if (await markerFile.exists()) {
      await _ensureMountPoints(rootfsDir);
      onProgress?.call('Listo', 1.0);
      return ContainerPaths(prootPath, rootfsDir.path);
    }

    if (await rootfsDir.exists()) {
      await rootfsDir.delete(recursive: true);
    }

    onProgress?.call('Cargando rootfs...', 0.05);
    final rootfsData = await rootBundle.load(_rootfsAsset);
    final rootfsBytes = rootfsData.buffer.asUint8List(rootfsData.offsetInBytes, rootfsData.lengthInBytes);

    await containerDir.create(recursive: true);
    await rootfsDir.create(recursive: true);

    onProgress?.call('Descomprimiendo Debian (1-3 min, no cierres la app)...', 0.1);
    await compute(_extractInBackground, _ExtractParams(rootfsBytes, containerDir.path));

    await _ensureMountPoints(rootfsDir);
    await markerFile.writeAsString('ok');
    onProgress?.call('Listo', 1.0);
    return ContainerPaths(prootPath, rootfsDir.path);
  }
}

Future<void> _extractInBackground(_ExtractParams params) async {
  final containerDir = Directory(params.containerDirPath);
  final rootfsDir = Directory('${containerDir.path}/rootfs');

  final tarBytes = XZDecoder().decodeBytes(params.rootfsBytes);

  final tempTar = File('${containerDir.path}/rootfs.tar');
  await tempTar.writeAsBytes(tarBytes);

  final result = await Process.run('tar', ['-xf', tempTar.path, '-C', rootfsDir.path]);
  await tempTar.delete();

  final bashFile = File('${rootfsDir.path}/usr/bin/bash');
  if (!await bashFile.exists()) {
    throw Exception(
      'La extracción del rootfs no generó /usr/bin/bash.\n'
      'Código tar: ${result.exitCode}\nstderr: ${result.stderr}',
    );
  }

  await Process.run('chmod', ['-R', 'u+rwX', rootfsDir.path]);
}
