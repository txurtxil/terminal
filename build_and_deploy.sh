#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Iniciando compilación de la APK en modo release...${NC}"

# 1. Compilar la APK
flutter build apk --release --android-skip-build-dependency-validation --android-skip-build-dependency-validation --android-skip-build-dependency-validation --android-skip-build-dependency-validation

# Verificar si la compilación fue exitosa
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Compilación exitosa.${NC}"
    
    # 2. Copiar la APK al servidor de descargas
    TARGET_DIR="/home/txurtxil/shared_linuxcontainer/"
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    
    echo "Copiando APK a $TARGET_DIR..."
    cp "$APK_PATH" "$TARGET_DIR"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}APK copiada con éxito a $TARGET_DIR${NC}"
    else
        echo "❌ Error al copiar la APK."
        exit 1
    fi
else
    echo "❌ Error durante la compilación de Flutter."
    exit 1
fi
