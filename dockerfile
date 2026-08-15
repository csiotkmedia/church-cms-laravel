FROM --platform=linux/amd64 php:8.2-fpm-bookworm
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /var/www/html

RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    git \
    unzip \
    zip \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libonig-dev \
    libicu-dev \
    libcurl4-openssl-dev \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists

# Configure PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mbstring \
        openssl \
        fileinfo \
        tokenizer \
        xml \
        ctype \
        bcmath \
        curl \
        gd \
        intl \
        zip \
        opcache

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install Node.js 18 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm --version \
    && node --version \
    && rm -rf /var/lib/apt/lists

# Copy application
COPY . /var/www/html

# Install PHP dependencies
RUN composer install \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Install JavaScript dependencies
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

# Nginx configuration
RUN rm -f /etc/nginx/sites-enabled/default

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# PHP-FPM configuration
RUN sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' \
    /usr/local/etc/php-fpm.d/www.conf

# Render uses port 10000 by default
EXPOSE 10000

# Start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
