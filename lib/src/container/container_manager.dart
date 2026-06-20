import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'container_bootstrap.dart';
import 'native_paths.dart';

class ContainerManager {
  static final ContainerManager _instance = ContainerManager._internal();
  factory ContainerManager() => _instance;
  ContainerManager._internal();

  Pty? _pty;
  Pty? get pty => _pty;

  String? _prootPath;
  String? _rootfsPath;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> initContainer({
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_ready) return;
    final bootstrap = ContainerBootstrap();
    final paths = await bootstrap.ensureExtracted(onProgress: onProgress);
    _prootPath = paths.prootPath;
    _rootfsPath = paths.rootfsPath;
    await _prepareLinks();
    _ready = true;
  }

  String? _ldLibraryPath;
  String? _loaderPath;
  String? _prootTmpPath;

  Future<void> _prepareLinks() async {
    final containerDirPath = Directory(_rootfsPath!).parent.path;

    final prootTmpDir = Directory('$containerDirPath/proot_tmp');
    if (!await prootTmpDir.exists()) {
      await prootTmpDir.create(recursive: true);
    }
    _prootTmpPath = prootTmpDir.path;

    final nativeLibDir = await NativePaths.getNativeLibraryDir();
    _loaderPath = '$nativeLibDir/libproot-loader.so';

    final linkDir = Directory('$containerDirPath/lib_links');
    if (await linkDir.exists()) {
      await linkDir.delete(recursive: true);
    }
    await linkDir.create(recursive: true);

    final tallocLink = Link('${linkDir.path}/libtalloc.so.2');
    await tallocLink.create('$nativeLibDir/libtalloc.so');

    _ldLibraryPath = '${linkDir.path}:$nativeLibDir';

    // Asegura DNS dentro del contenedor (persistente en cada arranque).
    final resolvConf = File('${_rootfsPath!}/etc/resolv.conf');
    try {
      await resolvConf.writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
    } catch (_) {}
  }

  /// Arranca proot dentro de un PTY real y devuelve el Pty para conectarlo a xterm.
  Pty startShell({int rows = 24, int columns = 80}) {
    _pty = Pty.start(
      _prootPath!,
      arguments: [
        '--link2symlink',
        '-0',
        '-r', _rootfsPath!,
        '-b', '/dev',
        '-b', '/proc',
        '-b', '/sys',
        '-b', '/system',
        '-b', '/apex',
        '-w', '/root',
        '/bin/bash',
        '--login',
      ],
      environment: {
        'HOME': '/root',
        'TERM': 'xterm-256color',
        'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'USER': 'root',
        'LANG': 'C.UTF-8',
        'PROOT_TMP_DIR': _prootTmpPath!,
        'PROOT_LOADER': _loaderPath!,
        'LD_LIBRARY_PATH': _ldLibraryPath!,
      },
      rows: rows,
      columns: columns,
    );
    return _pty!;
  }

  void dispose() {
    _pty?.kill();
    _pty = null;
    _ready = false;
  }
}
