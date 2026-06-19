import 'dart:io';

void main() {
  print("⚙️  Ejecutando auto-reparador nativo en Dart...");

  // 1. Reparación garantizada del NDK en build.gradle.kts
  final gradleFile = File('android/app/build.gradle.kts');
  if (gradleFile.existsSync()) {
    var content = gradleFile.readAsStringSync();
    
    // Si ya existe una versión, la actualizamos. Si no, la inyectamos.
    if (content.contains('ndkVersion')) {
      content = content.replaceAll(RegExp(r'ndkVersion\s*=\s*"[^"]+"'), 'ndkVersion = "28.2.13676358"');
    } else {
      content = content.replaceFirst(RegExp(r'android\s*\{'), 'android {\n    ndkVersion = "28.2.13676358"');
    }
    
    gradleFile.writeAsStringSync(content);
    print('✅ NDK version fijada a 28.2.13676358 de forma segura.');
  }

  // 2. Reparación del bloque onNonMatch (Dart 3 API) en ansi_parser.dart
  final dartFile = File('lib/src/terminal/ansi_parser.dart');
  if (dartFile.existsSync()) {
    var content = dartFile.readAsStringSync();
    
    // Busca cualquier closure colgante de segundo argumento y le asigna la etiqueta onNonMatch
    content = content.replaceAll(RegExp(r'\}\s*,\s*\(([^)]+)\)\s*\{'), '}, onNonMatch: (\$1) {');
    content = content.replaceAll(RegExp(r'\)\s*,\s*\(([^)]+)\)\s*\{'), '), onNonMatch: (\$1) {');
    content = content.replaceAll(RegExp(r'\}\s*,\s*\(([^)]+)\)\s*=>'), '}, onNonMatch: (\$1) =>');
    content = content.replaceAll(RegExp(r'\)\s*,\s*\(([^)]+)\)\s*=>'), '), onNonMatch: (\$1) =>');

    // Limpieza de seguridad por si el parche genera un duplicado en pasadas anteriores
    content = content.replaceAll('onNonMatch: onNonMatch:', 'onNonMatch:');

    dartFile.writeAsStringSync(content);
    print('✅ Analizador ANSI adaptado a Dart 3 correctamente.');
  }
}
