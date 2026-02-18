#!/bin/bash
LOG_FILE="/var/log/docker-entrypoint.log"
SSL_LOG_FILE="/var/log/ssl-setup.log"

# Funciones de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $1" | tee -a "$LOG_FILE"
}

log "======================================"
log "🚀 Iniciando configuración de Apache"
log "======================================"

# Crear directorios necesarios
mkdir -p /var/www/sites/logs /var/log/letsencrypt

# Detener Apache si está corriendo
if pgrep -x "apache2" > /dev/null; then
    log_warning "Apache ya está corriendo, deteniendo..."
    apachectl stop >> "$LOG_FILE" 2>&1 || true
    sleep 2
fi

# Copiar configuraciones de VirtualHosts
if [ -d "/etc/apache2/sites-config" ]; then
    log "📋 Copiando configuraciones de VirtualHosts..."

    cp /etc/apache2/sites-config/*.conf /etc/apache2/sites-available/ 2>/dev/null

    # Habilitar todos los sitios
    for conf in /etc/apache2/sites-available/*.conf; do
        if [ -f "$conf" ]; then
            site=$(basename "$conf" .conf)

            # Solo habilitar si no está ya habilitado
            if ! a2query -s "$site" > /dev/null 2>&1; then
                log "Habilitando sitio: $site"
                a2ensite "$site" >> "$LOG_FILE" 2>&1
            fi
        fi
    done
fi

# Validar configuración ANTES de iniciar Apache
log "🔍 Validando configuración de Apache..."
if apachectl configtest >> "$LOG_FILE" 2>&1; then
    log_success "Configuración válida"
else
    log_error "Configuración inválida, revisa $LOG_FILE"
fi

# INICIAR APACHE PRIMERO
log "🌐 Iniciando Apache..."
apachectl start >> "$LOG_FILE" 2>&1

if pgrep -x "apache2" > /dev/null; then
    log_success "Apache iniciado correctamente"
    sleep 3
else
    log_error "Apache no pudo iniciarse"
fi

# Iniciar cron
service cron start >> "$LOG_FILE" 2>&1
log_success "Cron iniciado"

# Función para crear VirtualHost SSL si no existe
create_ssl_vhost() {
    local domain=$1
    local docroot=$2
    local vhost_file="/etc/apache2/sites-available/${domain}-ssl.conf"

    if [ ! -f "$vhost_file" ]; then
        log "Creando VirtualHost SSL para ${domain}..."

        cat > "$vhost_file" << EOF
<VirtualHost *:443>
    ServerName ${domain}
    ServerAdmin webadmin@${domain}

    DocumentRoot ${docroot}

    <Directory ${docroot}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/www/sites/logs/${domain}-ssl-error.log
    CustomLog /var/www/sites/logs/${domain}-ssl-access.log combined

        # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/${domain}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${domain}/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
EOF

        a2ensite "${domain}-ssl" >> "$LOG_FILE" 2>&1
        log_success "VirtualHost SSL creado: ${domain}"
    fi
}

# Función para obtener certificado SSL
obtain_ssl_cert() {
    local domain=$1
    local email=$2

    log "🔐 Procesando SSL para: ${domain}"

    # Verificar si el certificado ya existe
    if [ -d "/etc/letsencrypt/live/${domain}" ]; then
        log_success "Certificado existente: ${domain}"
        return 0
    fi

    # Verificar DNS
    log "Verificando DNS para ${domain}..."
    if ! host "${domain}" > /dev/null 2>&1; then
        log_warning "DNS no resuelve para ${domain}, omitiendo SSL"
        return 1
    fi

    # Intentar obtener certificado
    log "Ejecutando certbot para ${domain}..."
    certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --non-interactive \
        --agree-tos \
        --email "${email}" \
        --domains "${domain}" \
        --keep-until-expiring \
        2>&1 | tee -a "$SSL_LOG_FILE"

    local certbot_exit=$?

    if [ $certbot_exit -eq 0 ]; then
        log_success "✅ Certificado obtenido: ${domain}"

        # Determinar DocumentRoot basado en el dominio
        local docroot="/var/www/html"
        if [[ "$domain" == *"maestro"* ]]; then
            docroot="/var/www/html/maestro"
        elif [[ "$domain" == "artesco.com.pe" ]]; then
            docroot="/var/www/html/multi-site/public"
        fi

        # Crear VirtualHost SSL
        create_ssl_vhost "$domain" "$docroot"

        return 0
    else
        log_error "❌ Error al obtener certificado: ${domain}"
        return 1
    fi
}

# Procesar SSL solo si está configurado
if [ ! -z "$SSL_DOMAINS" ] && [ ! -z "$SSL_EMAIL" ]; then
    log "======================================"
    log "🔐 CONFIGURACIÓN SSL"
    log "======================================"
    log "📧 Email: $SSL_EMAIL"
    log "🌍 Dominios: $SSL_DOMAINS"

    # Cron para renovación
    echo "0 */12 * * * root certbot renew --quiet --post-hook 'apachectl graceful' >> /var/log/letsencrypt/renew.log 2>&1" > /etc/cron.d/certbot-renew
    chmod 0644 /etc/cron.d/certbot-renew
    log_success "Renovación automática configurada"

    # Convertir dominios en array
    IFS=',' read -ra DOMAIN_ARRAY <<< "$SSL_DOMAINS"

    ssl_success_count=0
    ssl_fail_count=0

    # Procesar cada dominio
    for domain_entry in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain_entry" | xargs)

        if [ ! -z "$domain" ]; then
            log "--------------------------------------"
            if obtain_ssl_cert "$domain" "$SSL_EMAIL"; then
                ((ssl_success_count++))
            else
                ((ssl_fail_count++))
            fi
        fi
    done

    log "======================================"
    log "📊 RESUMEN SSL"
    log "======================================"
    log "✅ Exitosos: $ssl_success_count"
    log "❌ Fallidos: $ssl_fail_count"
    log "======================================"

    # Recargar Apache
    if [ $ssl_success_count -gt 0 ]; then
        log "🔄 Recargando Apache..."
        apachectl graceful >> "$LOG_FILE" 2>&1
        sleep 2
        log_success "Apache recargado"
    fi

else
    log "======================================"
    log_warning "SSL NO CONFIGURADO"
    log "======================================"
fi

# Información del sistema
log "======================================"
log "📊 INFORMACIÓN DEL SISTEMA"
log "======================================"
log "🐘 PHP: $(php -v | head -n 1)"

if php -m | grep -i mysqli > /dev/null 2>&1; then
    log_success "mysqli: habilitado"
fi

if php -m | grep -i phalcon > /dev/null 2>&1; then
    phalcon_version=$(php --ri phalcon 2>/dev/null | grep "Version" | awk '{print $3}')
    log_success "Phalcon: $phalcon_version"
fi

log "======================================"
log "🌐 VirtualHosts configurados:"
apachectl -S 2>&1 | grep -E "(port|namevhost)" | tee -a "$LOG_FILE"
log "======================================"

log "🎉 SERVIDOR LISTO"

# Detener Apache antes de FOREGROUND
apachectl stop >> "$LOG_FILE" 2>&1
sleep 1

# Iniciar en FOREGROUND
log "🚀 Iniciando Apache en modo FOREGROUND..."
exec apache2ctl -D FOREGROUND