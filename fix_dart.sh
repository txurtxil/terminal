#!/bin/bash

FILE="/home/txurtxil/linux_container_build/lib/src/terminal/ansi_parser.dart"

echo "⚙️  Corrigiendo código Dart en $FILE..."

# 1. Cambiamos el tipo de la variable de 'int?' a 'Color?' para compatibilidad con MaterialColor
sed -i 's/int? currentColor/Color? currentColor/g' "$FILE"

# 2. Arreglamos el cambio de API en splitMapJoin (Actualización a Dart 3)
# Convertimos el primer closure posicional en el parámetro nombrado 'onMatch:'
sed -i -E 's/splitMapJoin\(ansiRegex,\s*\((match|Match match)\)/splitMapJoin(ansiRegex, onMatch: (\1)/g' "$FILE"

# Convertimos el segundo closure posicional en el parámetro nombrado 'onNonMatch:'
sed -i -E 's/\},\s*\(([a-zA-Z_]+|String [a-zA-Z_]+)\)\s*\{/\}, onNonMatch: (\1) {/g' "$FILE"

echo "✅ Analizador ANSI parcheado correctamente."
echo "🚀 Relanzando build_and_deploy.sh..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
