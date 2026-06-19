import 'dart:io';

void main() {
  print("⚙️  Ejecutando cirugía definitiva en Dart...");

  // 1. NDK Fix: Forzar al final del archivo para que Gradle no pueda ignorarlo
  final gradleFile = File('android/app/build.gradle.kts');
  if (gradleFile.existsSync()) {
    var content = gradleFile.readAsStringSync();
    
    // Limpiamos intentos anteriores para no ensuciar
    content = content.replaceAll(RegExp(r'ndkVersion\s*=\s*"[^"]*"'), '');
    
    // Añadimos el bloque al final. Gradle siempre aplica la última configuración leída.
    content += '\n\nandroid {\n    ndkVersion = "28.2.13676358"\n}\n';
    gradleFile.writeAsStringSync(content);
    print('✅ NDK version forzada al final de app/build.gradle.kts.');
  }

  // 2. Dart API Fix: Modificación ultrasegura de splitMapJoin
  final dartFile = File('lib/src/terminal/ansi_parser.dart');
  if (dartFile.existsSync()) {
    var content = dartFile.readAsStringSync();
    
    // Dividimos el archivo exactamente en las llamadas a splitMapJoin
    var parts = content.split('splitMapJoin');
    
    // Iteramos sobre las partes para parchear la que falla sin tocar el resto de tu lógica
    for (var i = 1; i < parts.length; i++) {
        parts[i] = parts[i].replaceFirstMapped(
          RegExp(r',\s*\(\s*([a-zA-Z_][a-zA-Z0-9_\s]*?)\s*\)\s*(=>|\{)'), 
          (match) => ', onNonMatch: (${match.group(1)}) ${match.group(2)}'
        );
    }
    
    // Reconstruimos el archivo
    content = parts.join('splitMapJoin');
    
    // Limpieza de seguridad
    content = content.replaceAll('onNonMatch: onNonMatch:', 'onNonMatch:');
    
    dartFile.writeAsStringSync(content);
    print('✅ Analizador ANSI parcheado con precisión quirúrgica.');
  }
}
