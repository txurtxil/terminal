import 'package:flutter/foundation.dart';
import '../container/container_manager.dart';
import 'dart:async';

class TerminalBridge {
  final ContainerManager _containerManager = ContainerManager();

  @pragma('vm:no-introspection')
  Stream<String> sendCommandStream(String command) {
    return _containerManager.executeCommandStream(command);
  }

  Future<void> initialize() async {
    await _containerManager.initContainer();
  }
}
