import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../container/container_manager.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final ContainerManager _manager = ContainerManager();

  String _status = 'Iniciando...';
  double _progress = 0.0;
  bool _booting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _manager.initContainer(onProgress: (status, progress) {
        if (!mounted) return;
        setState(() {
          _status = status;
          _progress = progress;
        });
      });

      final pty = _manager.startShell(
        rows: _terminal.viewHeight,
        columns: _terminal.viewWidth,
      );

      // PTY -> Terminal (salida del shell a la pantalla)
      pty.output
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .listen(_terminal.write);

      // Terminal -> PTY (teclado del usuario al shell)
      _terminal.onOutput = (data) {
        pty.write(const Utf8Encoder().convert(data));
      };

      // Reajuste de tamaño del terminal -> PTY
      _terminal.onResize = (w, h, pw, ph) {
        pty.resize(h, w);
      };

      pty.exitCode.then((code) {
        if (!mounted) return;
        _terminal.write('\r\n[proceso finalizado, código $code]\r\n');
      });

      if (!mounted) return;
      setState(() => _booting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _booting = false;
      });
    }
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'ERROR:\n$_error',
                style: const TextStyle(color: Colors.red, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      );
    }

    if (_booting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_status, style: const TextStyle(color: Colors.green, fontFamily: 'monospace')),
                const SizedBox(height: 16),
                SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: TerminalView(_terminal),
      ),
    );
  }
}
