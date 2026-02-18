# Etapa 1: Compilar Phalcon
FROM ubuntu:24.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV MAKEFLAGS="-j1"

# Instalar dependencias base
RUN apt-get update && \
    apt-get install -y software-properties-common

# Agregar PPA de PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update

# Instalar herramientas de compilación
RUN apt-get install -y \
    php8.3-dev \
    php8.3-xml \
    php-pear \
    gcc \
    make \
    autoconf \
    libc-dev \
    pkg-config \
    git \
    wget

# Instalar PSR
RUN pecl channel-update pecl.php.net && \
    pecl install psr

# Descargar Phalcon desde GitHub
RUN cd /tmp && \
    git config --global http.postBuffer 524288000 && \
    git clone --depth=1 --branch=5.8.0 https://github.com/phalcon/cphalcon.git cphalcon || \
    wget https://github.com/phalcon/cphalcon/archive/refs/tags/v5.8.0.tar.gz && \
    tar -xzf v5.8.0.tar.gz && \
    mv cphalcon-5.8.0 cphalcon

# Compilar Phalcon
RUN cd /tmp/cphalcon/build && \
    ./install

# Etapa 2: Imagen final
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Lima

# Instalar dependencias base
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common

    # Agregar PPA de PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update

# Instalar Apache y PHP
RUN apt-get install -y \
    apache2 \
    libapache2-mod-php8.3 \
    php8.3 \
    php8.3-cli \
    php8.3-common

# Instalar extensiones PHP
RUN apt-get install -y \
    php8.3-mysql \
    php8.3-mysqli \
    php8.3-zip \
    php8.3-gd \
    php8.3-mbstring \
    php8.3-curl \
    php8.3-xml \
    php8.3-bcmath \
    php8.3-opcache \
    php8.3-pdo \
    php8.3-fileinfo \
    php8.3-exif \
    php8.3-intl

# Instalar extensiones adicionales
RUN apt-get install -y \
    php8.3-calendar \
    php8.3-ftp \
    php8.3-gettext \
    php8.3-readline \
    php8.3-shmop \
    php8.3-sockets \
    php8.3-sysvmsg \
    php8.3-sysvsem \
    php8.3-sysvshm \
    php8.3-xsl

# Instalar Certbot y utilidades
RUN apt-get install -y \
    certbot \
    python3-certbot-apache \
    openssl \
    nano \
    graphicsmagick \
    imagemagick \
    ghostscript \
    mysql-client \
    iputils-ping \
    locales \
    sqlite3 \
    ca-certificates \
    curl \
    unzip \
    git \
    wget \
    cron

# Limpiar caché de apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Copiar PSR y Phalcon compilados desde builder
COPY --from=builder /usr/lib/php/20230831/psr.so /usr/lib/php/20230831/
COPY --from=builder /usr/lib/php/20230831/phalcon.so /usr/lib/php/20230831/

# Habilitar extensiones PSR y Phalcon
RUN echo "extension=psr.so" > /etc/php/8.3/mods-available/psr.ini && \
    echo "extension=phalcon.so" > /etc/php/8.3/mods-available/phalcon.ini && \
    phpenmod psr phalcon

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Configurar locales
RUN locale-gen en_US.UTF-8 en_GB.UTF-8 de_DE.UTF-8 es_ES.UTF-8 \
    fr_FR.UTF-8 it_IT.UTF-8 km_KH sv_SE.UTF-8 fi_FI.UTF-8

# Configurar Apache
RUN a2enmod rewrite ssl headers && \
    echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf && \
    a2enconf servername && \
    a2dissite 000-default

# Configurar PHP
RUN sed -i 's/memory_limit = .*/memory_limit = 1024M/' /etc/php/8.3/apache2/php.ini && \
    sed -i 's/max_execution_time = .*/max_execution_time = 3000/' /etc/php/8.3/apache2/php.ini && \
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 1024M/' /etc/php/8.3/apache2/php.ini && \
    sed -i 's/post_max_size = .*/post_max_size = 512M/' /etc/php/8.3/apache2/php.ini

# Crear directorio para certificados SSL
RUN mkdir -p /etc/letsencrypt

# Copiar y configurar script de inicio
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Exponer puertos
EXPOSE 80 443

# Directorio de trabajo
WORKDIR /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=40s \
    CMD pgrep apache2 || exit 1

# Punto de entrada
ENTRYPOINT ["docker-entrypoint.sh"]