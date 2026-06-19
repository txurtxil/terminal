import 'package:flutter/material.dart';

class AnsiParser {
  static List<TextSpan> parse(String input) {
    List<TextSpan> spans = [];
    Color? currentColor;
    FontWeight? currentWeight;
    double? currentSize;

    int i = 0;
    while (i < input.length) {
      if (input.startsWith('\x1B[', i)) {
        int end = input.indexOf('m', i);
        if (end == -1) break;
        String code = input.substring(i + 1, end);
        if (code.contains('0')) {
          currentColor = null;
          currentWeight = FontWeight.normal;
          currentSize = 14.0;
        } else if (code.contains('1')) {
          currentWeight = FontWeight.bold;
        } else if (code.contains('31')) {
          currentColor = Colors.red;
        } else if (code.contains('32')) {
          currentColor = Colors.green;
        } else if (code.contains('33')) {
          currentColor = Colors.yellow;
        } else if (code.contains('34')) {
          currentColor = Colors.blue;
        } else if (code.contains('36')) {
          currentColor = Colors.cyan;
        } else if (code.contains('37')) {
          currentColor = Colors.white;
        } else if (code.contains('35')) {
          currentColor = const Color(0xFFFF00FF);
        } else if (code.contains('39')) {
          currentColor = null;
        }
        i = end + 1;
      } else {
        int nextCode = input.indexOf('\x1B[', i);
        if (nextCode == -1) nextCode = input.length;
        String text = input.substring(i, nextCode);
        if (text.isNotEmpty) {
          spans.add(TextSpan(
            text: text,
            style: TextStyle(
              color: currentColor,
              fontWeight: currentWeight,
              fontSize: currentSize,
            ),
          ));
        }
        i = nextCode;
      }
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: input));
    }
    return spans;
  }
}
