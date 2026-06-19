#!/bin/bash

# Definimos la ruta del archivo
GRADLE_FILE="/home/txurtxil/linux_container_build/android/build.gradle.kts"

echo "⚙️  Inyectando 'apply false' exacto en $GRADLE_FILE..."

# Buscamos la cadena exacta sin versión y le añadimos el apply false
sed -i 's/id("com.android.application")/id("com.android.application") apply false/g' "$GRADLE_FILE"
sed -i 's/id("org.jetbrains.kotlin.android")/id("org.jetbrains.kotlin.android") apply false/g' "$GRADLE_FILE"

# Limpieza rápida por si alguna vez se duplica
sed -i 's/apply false apply false/apply false/g' "$GRADLE_FILE"

echo "✅ Plugins corregidos con éxito."
echo "🚀 Relanzando build_and_deploy.sh..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
