#!/bin/bash

# Definimos la ruta del archivo
GRADLE_FILE="/home/txurtxil/linux_container_build/android/build.gradle.kts"

echo "⚙️  Inyectando 'apply false' en los plugins de $GRADLE_FILE..."

# 1. Parcheamos los plugins con formato de paréntesis: id("...") version "..."
sed -i -E "s/(id\s*\(\s*[\"']com\.android\.application[\"']\s*\)\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"
sed -i -E "s/(id\s*\(\s*[\"']com\.android\.library[\"']\s*\)\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"
sed -i -E "s/(id\s*\(\s*[\"']org\.jetbrains\.kotlin\.android[\"']\s*\)\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"

# 2. Parcheamos los plugins con formato sin paréntesis (Groovy style o KTS delegators): id "..." version "..."
sed -i -E "s/(id\s*[\"']com\.android\.application[\"']\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"
sed -i -E "s/(id\s*[\"']com\.android\.library[\"']\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"
sed -i -E "s/(id\s*[\"']org\.jetbrains\.kotlin\.android[\"']\s*version\s*[\"'][^\"']+[\"'])/\1 apply false/g" "$GRADLE_FILE"

# 3. Limpiamos posibles duplicados (por si el script se ejecuta varias veces o ya había algún 'apply false' puesto a medias)
sed -i "s/ apply false apply false/ apply false/g" "$GRADLE_FILE"

echo "✅ Plugins corregidos correctamente."
echo "🚀 Relanzando build_and_deploy.sh..."

# Ejecutamos el script de despliegue
cd /home/txurtxil/linux_container_build && ./build_and_deploy.sh
