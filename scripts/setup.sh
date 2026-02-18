#!/bin/bash

echo "🚀 Script de configuración para Artesco Docker"
echo "=============================================="

# Verificar si existe .env
if [ ! -f .env ]; then
    echo "📋 No se encontró archivo .env, copiando desde .env.example..."
    cp .env.example .env
    echo "✅ Archivo .env creado"
    echo ""
    echo "⚠️  IMPORTANTE: Edita el archivo .env y configura tus credenciales"
    echo ""
else
    echo "✅ Archivo .env encontrado"
fi

# Crear directorios necesarios
echo "📁 Creando directorios necesarios..."
#mkdir -p html/multi-site/public
#mkdir -p html/maestro
mkdir -p html/logs
mkdir -p vhosts
mkdir -p mysql-config
mkdir -p mysql-init

# Permisos
echo "🔐 Configurando permisos..."
chmod -R 755 html
chmod -R 777 html/logs
chmod +x docker-entrypoint.sh

echo ""
echo "✅ Configuración completada"
echo ""
echo "📝 Próximos pasos:"
echo "1. Edita el archivo .env con tus configuraciones"
echo "2. Ejecuta: docker-compose up -d --build"
echo "3. Verifica logs: docker-compose logs -f"
