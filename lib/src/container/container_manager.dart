import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

class ContainerManager {
  static final ContainerManager _instance = ContainerManager._internal();
  factory ContainerManager() => _instance;
  ContainerManager._internal();

  // Paths now relative to the project root
  static const String prootBinary = '/root/Documents/Codex/2026-06-18/hola-3/linux_container/proot_bin';
  static const String rootfsPath = '/root/Documents/Codex/2026-06-18/hola-3/linux_container/rootfs_local';

  Stream<String> executeCommandStream(String command) async* {
    try {
      final List<String> args = command.split(' ').where((s) => s.isNotEmpty).toList();
      
      final process = await Process.start(
        prootBinary,
        [
          '-r', rootfsPath,
          '-0',
          ...args
        ],
      );

      final stdout = process.stdout;
      final stderr = process.stderr;

      // Simple stream combination
      await for (var line in _combineStreams([stdout, stderr])) {
        yield line;
      }
    } catch (e) {
      yield 'Exception: $e';
    }
  }

  Stream<String> _combineStreams(List<Stream> streams) async* {
    for (var stream in streams) {
      await for (var data in stream) {
        final line = String.fromCharCodes(data);
        if (line.contains('\n')) {
          yield line;
        }
      }
    }
  }

  Future<void> initContainer() async {
    final dir = Directory(rootfsPath);
    if (!await dir.exists()) {
      print('Warning: RootFS directory $rootfsPath does not exist yet.');
    }
    print('Initializing PROOT container...');
  }
}
