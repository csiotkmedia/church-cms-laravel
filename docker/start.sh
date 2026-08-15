#!/bin/sh

set -e

echo "Starting Church CMS..."

# Ensure Laravel writable directories exist
mkdir -p \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache \
    /var/www/html/public/uploads

chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache \
    /var/www/html/public

# Start PHP-FPM
php-fpm -D

# Start Nginx in foreground
nginx -g "daemon off;"
