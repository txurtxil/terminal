#!/bin/bash

DART_FILE="/home/txurtxil/linux_container_build/lib/src/terminal/ansi_parser.dart"
GRADLE_FILE_APP="/home/txurtxil/linux_container_build/android/app/build.gradle.kts"

echo "⚙️  Aplicando correcciones finales..."

# 1. Fix de NDK Version
# Insertamos ndkVersion justo después de abrir el bloque android { en el módulo app
sed -i 's/android {/android {\n    ndkVersion = "28.2.13676358"/g' "$GRADLE_FILE_APP"
echo "✅ Versión de NDK fijada en app/build.gradle.kts"

# 2. Fix de Colors.magenta
# Reemplazamos el color inexistente por su valor hexadecimal puro nativo
sed -i 's/Colors.magenta/const Color(0xFFFF00FF)/g' "$DART_FILE"
echo "✅ Colores ANSI magenta corregidos."

# 3. Fix del último splitMapJoin rebelde (Línea 13)
# Buscamos de forma inteligente cualquier closure que empiece por coma y no tenga etiqueta onNonMatch
perl -0777 -pi -e 's/,\s*(?!onMatch|onNonMatch)\(([a-zA-Z_][a-zA-Z0-9_]*)\)\s*(\{|=>)/, onNonMatch: ($1) $2/g' "$DART_FILE"

# Limpieza rápida por si el parche genera algún duplicado accidental
sed -i 's/onNonMatch: onNonMatch:/onNonMatch:/g' "$DART_FILE"
echo "✅ Analizador ANSI completamente pulido."

echo "🚀 Relanzando build_and_deploy.sh..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
