#!/bin/bash

# Definimos la ruta exacta del archivo a parchear
GRADLE_FILE="/home/txurtxil/linux_container_build/android/build.gradle.kts"

echo "⚙️  Aplicando parche automático en $GRADLE_FILE..."

# Usamos sed para buscar el bloque de la tarea 'clean' (cubriendo las variaciones
# comunes de sintaxis de Kotlin DSL) y lo eliminamos hasta su llave de cierre.
sed -i '/tasks.register.*"clean"/,/}/d' "$GRADLE_FILE"

echo "✅ Tarea 'clean' redundante eliminada."
echo "🚀 Relanzando build_and_deploy.sh..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
