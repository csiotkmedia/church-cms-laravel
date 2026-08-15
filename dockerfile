FROM --platform=linux/amd64 php:8.2-fpm-bookworm

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /var/www/html

# System dependencies
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

# PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        xml \
        bcmath \
        curl \
        gd \
        intl \
        zip \
        opcache

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*

# Copy application
COPY . /var/www/html

# PHP dependencies
RUN composer --version

RUN composer diagnose -vvv

RUN composer validate --no-check-publish

RUN composer install \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-dev \
    -vvv

# JavaScript dependencies
RUN npm install

# Build frontend assets
RUN npm run production

# Laravel writable directories
RUN mkdir -p \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
        public/uploads \
    && chmod -R 775 storage bootstrap/cache public

# Nginx
RUN rm -f /etc/nginx/sites-enabled/default

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# PHP-FPM
RUN sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' \
    /usr/local/etc/php-fpm.d/www.conf

EXPOSE 10000

# Startup script
COPY docker/start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
