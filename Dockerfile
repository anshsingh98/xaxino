FROM php:8.3-fpm-alpine

# System dependencies + PHP extensions required by the app
RUN apk add --no-cache nginx curl bash mysql-client icu-dev oniguruma-dev libzip-dev zip libpng-dev freetype-dev libjpeg-turbo-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql bcmath gd mbstring intl zip exif pcntl opcache \
    && apk del icu-dev oniguruma-dev libzip-dev libpng-dev freetype-dev libjpeg-turbo-dev

# PHP tuning
COPY docker/php.ini /usr/local/etc/php/conf.d/zz-xaxino.ini

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Install PHP dependencies first (better layer caching)
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --ignore-platform-reqs

# App source
COPY . .

# Prepare env + dirs BEFORE dump-autoload (package:discover needs them)
RUN cp -n .env.example .env \
    && mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views \
    && mkdir -p storage/logs storage/app/public bootstrap/cache temp database \
    && touch storage/logs/laravel.log database/database.sqlite \
    && composer dump-autoload --optimize \
    && chown -R www-data:www-data storage bootstrap/cache temp database \
    && chmod -R 775 storage bootstrap/cache temp database

# Nginx config + entrypoint
COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8000

CMD ["/start.sh"]

