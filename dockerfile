FROM --platform=linux/amd64 php:8.2-fpm-bookworm

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /var/www/html

# ---------------------------------------------------------
# System dependencies
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    git \
    unzip \
    zip \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype-dev \
    libxml2-dev \
    libonig-dev \
    libicu-dev \
    libcurl4-openssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# PHP extensions
# ---------------------------------------------------------
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_mysql \
        mbstring \
        xml \
        bcmath \
        curl \
        gd \
        intl \
        zip \
        opcache

# ---------------------------------------------------------
# Composer
# ---------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN composer --version

# ---------------------------------------------------------
# Node.js 22
# ---------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Copy Composer files and local package repository
# ---------------------------------------------------------
COPY composer.json composer.lock ./

COPY custompackages ./custompackages

# ---------------------------------------------------------
# Validate Composer configuration
# ---------------------------------------------------------
RUN composer validate --no-check-publish

# ---------------------------------------------------------
# Install PHP dependencies
#
# IMPORTANT:
# Do NOT run "composer diagnose" during the Docker build.
# It is a diagnostic command and is not required to build
# the Laravel application.
# ---------------------------------------------------------
RUN composer install \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-dev

# ---------------------------------------------------------
# Copy application
# ---------------------------------------------------------
COPY . /var/www/html

# ---------------------------------------------------------
# JavaScript dependencies
# ---------------------------------------------------------
RUN npm ci

# ---------------------------------------------------------
# Build frontend assets
# ---------------------------------------------------------
RUN npm run production

# ---------------------------------------------------------
# Laravel writable directories
# ---------------------------------------------------------
RUN mkdir -p \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
        public/uploads \
    && chmod -R 775 \
        storage \
        bootstrap/cache \
        public

# ---------------------------------------------------------
# Nginx
# ---------------------------------------------------------
RUN rm -f /etc/nginx/sites-enabled/default

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# ---------------------------------------------------------
# PHP-FPM
# ---------------------------------------------------------
RUN sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' \
    /usr/local/etc/php-fpm.d/www.conf

# ---------------------------------------------------------
# Render port
# ---------------------------------------------------------
EXPOSE 10000

# ---------------------------------------------------------
# Startup script
# ---------------------------------------------------------
COPY docker/start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
