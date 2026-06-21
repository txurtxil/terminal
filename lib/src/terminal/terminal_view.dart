import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm/xterm.dart';
import '../container/container_manager.dart';
import 'terminal_keybar.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final TerminalController _terminalController = TerminalController();
  final ContainerManager _manager = ContainerManager();

  final List<String> _logLines = [];
  double? _progress = 0.0;
  bool _spinning = false;
  bool _booting = true;
  bool _shellStarted = false;
  String? _error;

  double _fontSize = 14.0;
  static const double _minFont = 8.0;
  static const double _maxFont = 28.0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _appendLog(String line, {bool spinning = false, double? progress}) {
    if (!mounted) return;
    setState(() {
      _logLines.add(line);
      _spinning = spinning;
      if (progress != null) _progress = progress;
    });
  }

  Future<void> _boot() async {
    try {
      await _manager.initContainer(log: _appendLog);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _booting = false);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted) _startShell();
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _booting = false;
      });
    }
  }

  void _startShell() {
    if (_shellStarted) return;
    _shellStarted = true;

    final cols = _terminal.viewWidth;
    final rows = _terminal.viewHeight;

    final pty = _manager.startShell(
      rows: rows > 0 ? rows : 24,
      columns: cols > 0 ? cols : 80,
    );

    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(_terminal.write);

    _terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    _terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };

    pty.exitCode.then((code) {
      if (!mounted) return;
      _terminal.write('\r\n[proceso finalizado, código $code]\r\n');
    });
  }

  void _changeFont(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFont, _maxFont);
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      _terminal.textInput(text);
    }
  }

  void _copyScreen() {
    final buffer = _terminal.buffer;
    final sb = StringBuffer();
    for (int i = 0; i < _terminal.viewHeight; i++) {
      final line = buffer.lines[buffer.height - _terminal.viewHeight + i];
      sb.writeln(line.toString().trimRight());
    }
    Clipboard.setData(ClipboardData(text: sb.toString().trimRight()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pantalla copiada al portapapeles'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste, color: Colors.greenAccent),
              title: const Text('Pegar', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Pega el portapapeles en el terminal', style: TextStyle(color: Colors.white54)),
              onTap: () { Navigator.pop(ctx); _paste(); },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all, color: Colors.greenAccent),
              title: const Text('Copiar pantalla', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Copia el texto visible', style: TextStyle(color: Colors.white54)),
              onTap: () { Navigator.pop(ctx); _copyScreen(); },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.format_size, color: Colors.greenAccent),
              title: const Text('Tamaño de fuente', style: TextStyle(color: Colors.white)),
              subtitle: Text('${_fontSize.toInt()} pt', style: const TextStyle(color: Colors.white54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () { _changeFont(-1); Navigator.pop(ctx); _showMenu(); }),
                  IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () { _changeFont(1); Navigator.pop(ctx); _showMenu(); }),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.greenAccent),
              title: const Text('Limpiar pantalla', style: TextStyle(color: Colors.white)),
              onTap: () { _terminal.charInput('l'.codeUnitAt(0), ctrl: true); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.amberAccent),
              title: const Text('Reiniciar shell', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _restartShell(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _restartShell() {
    _manager.dispose();
    _shellStarted = false;
    _terminal.write('\r\n\x1b[1;33m[reiniciando shell...]\x1b[0m\r\n');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startShell();
    });
  }

  @override
  void dispose() {
    _manager.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  Color _lineColor(String line) {
    if (line.contains('[ OK ]')) return Colors.greenAccent;
    if (line.contains('[ .. ]')) return Colors.amberAccent;
    if (line.contains('[ !! ]')) return Colors.orangeAccent;
    return Colors.white70;
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
              child: Text('ERROR:\n$_error', style: const TextStyle(color: Colors.red, fontFamily: 'monospace')),
            ),
          ),
        ),
      );
    }

    if (_booting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LinuxContainer · arranque', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _logLines.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        _logLines[i],
                        style: TextStyle(color: _lineColor(_logLines[i]), fontFamily: 'monospace', fontSize: 13, height: 1.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _spinning ? null : _progress, backgroundColor: Colors.white10, color: Colors.greenAccent),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                autofocus: true,
                backgroundOpacity: 1.0,
                deleteDetection: true,
                keyboardType: TextInputType.visiblePassword,
                textStyle: TerminalStyle(fontSize: _fontSize, fontFamily: 'monospace'),
              ),
            ),
            TerminalKeybar(
              terminal: _terminal,
              onFontIncrease: () => _changeFont(1),
              onFontDecrease: () => _changeFont(-1),
              onMenu: _showMenu,
            ),
          ],
        ),
      ),
    );
  }
}
