import 'package:flutter/material.dart';
import '../bridge/terminal_bridge.dart';
import 'ansi_parser.dart';
import 'dart:async';

class TerminalView extends StatefulWidget {
  const TerminalView({super.key});

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final TerminalBridge _terminalBridge = TerminalBridge();
  final TextEditingController _controller = TextEditingController();
  final List<List<TextSpan>> _history = [];
  bool _isProcessing = false;
  StreamSubscription? _outputSubscription;

  @override
  void initState() {
    super.initState();
    _terminalBridge.initialize();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    super.dispose();
  }

  void _handleCommand() async {
    if (_controller.text.trim().isEmpty || _isProcessing) return;

    setState(() {
      _history.add(AnsiParser.parse('User: ${_controller.text}'));
      _isProcessing = true;
    });

    final command = _controller.text;
    _controller.clear();

    _outputSubscription?.cancel();
    _outputSubscription = _terminalBridge.sendCommandStream(command).listen(
      (String line) {
        if (mounted) {
          setState(() {
            _history.add(AnsiParser.parse(line));
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _history.add(AnsiParser.parse('Error: $error'));
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                return RichText(
                  text: TextSpan(
                    children: _history[index],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter command...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
