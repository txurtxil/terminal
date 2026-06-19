#!/bin/bash

FILE="/home/txurtxil/linux_container_build/lib/src/terminal/ansi_parser.dart"

echo "⚙️  Buscando y corrigiendo cierres multilínea en $FILE..."

# Usamos perl con -0777 para procesar el archivo completo de una pasada.
# Esto detecta el "}, (variable) {" sin importar cuántos saltos de línea haya en medio.
perl -0777 -pi -e 's/(\}\s*,\s*)\(([^)]+)\)\s*(\{|=>)/$1onNonMatch: ($2) $3/g' "$FILE"

echo "✅ Parche aplicado correctamente. Relanzando compilación..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
