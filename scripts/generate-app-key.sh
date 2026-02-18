#!/bin/bash

# Generar APP_KEY para Laravel
APP_KEY=$(openssl rand -base64 32)
ENCODED_KEY="base64:$APP_KEY"

echo "🔑 APP_KEY generado:"
echo "$ENCODED_KEY"
echo ""
echo "Copia esta línea en tu archivo .env:"
echo "APP_KEY=$ENCODED_KEY"
