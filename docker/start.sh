#!/bin/bash
set -e
cd /var/www/html

# ------------------------------------------------------------------
# 1. .env setup
# ------------------------------------------------------------------
if [ ! -f .env ]; then
    cp .env.example .env
fi

# Sync runtime env vars into .env so artisan (CLI) sees the same config
set_env() {
    KEY="$1"; VAL="$2"
    if [ -z "$VAL" ]; then return; fi
    if grep -qE "^${KEY}=" .env; then
        sed -i "s|^${KEY}=.*|${KEY}=\"${VAL}\"|" .env
    else
        echo "${KEY}=\"${VAL}\"" >> .env
    fi
}

set_env APP_ENV "${APP_ENV:-production}"
set_env APP_DEBUG "${APP_DEBUG:-false}"
set_env APP_URL "$APP_URL"
set_env DB_CONNECTION "${DB_CONNECTION:-mysql}"
set_env DB_HOST "$DB_HOST"
set_env DB_PORT "${DB_PORT:-3306}"
set_env DB_DATABASE "$DB_DATABASE"
set_env DB_USERNAME "$DB_USERNAME"
set_env DB_PASSWORD "$DB_PASSWORD"

# Generate APP_KEY if missing (idempotent)
if ! grep -qE '^APP_KEY=base64.+' .env; then
    php artisan key:generate --force
fi

# ------------------------------------------------------------------
# 2. Ensure writable dirs (ephemeral FS on Render recreates them)
# ------------------------------------------------------------------
mkdir -p storage/framework/cache/data storage/framework/sessions \
         storage/framework/testing storage/framework/views \
         storage/logs storage/app/public bootstrap/cache temp
chown -R www-data:www-data storage bootstrap/cache temp || true
chmod -R 775 storage bootstrap/cache temp || true

# ------------------------------------------------------------------
# 3. Database: wait for it, import dump if empty, migrate
# ------------------------------------------------------------------
if [ "$DB_CONNECTION" = "mysql" ] && [ -n "$DB_HOST" ]; then
    MY="mysql -h ${DB_HOST} -P ${DB_PORT:-3306} -u ${DB_USERNAME} -p${DB_PASSWORD}"
    echo "Waiting for database ${DB_HOST}:${DB_PORT:-3306}..."
    for i in $(seq 1 60); do
        if $MY -e 'SELECT 1' >/dev/null 2>&1; then break; fi
        if [ "$i" -eq 60 ]; then echo "ERROR: database not reachable"; exit 1; fi
        sleep 3
    done

    if [ -f database/xaxino_mysql.sql ]; then
        TABLES=$($MY "$DB_DATABASE" -N -e 'SHOW TABLES;' 2>/dev/null | wc -l)
        if [ "$TABLES" -eq 0 ]; then
            echo "Importing database dump (first boot)..."
            $MY "$DB_DATABASE" < database/xaxino_mysql.sql
        fi
    fi
    php artisan migrate --force || echo "WARN: migrate skipped"
else
    # SQLite fallback
    touch database/database.sqlite
    chown www-data:www-data database/database.sqlite || true
    php artisan migrate --force || echo "WARN: migrate skipped"
fi

# ------------------------------------------------------------------
# 4. Bind nginx to Render's $PORT (default 8000 locally)
# ------------------------------------------------------------------
sed -i "s/^    listen .*/    listen ${PORT:-8000};/" /etc/nginx/http.d/default.conf

# ------------------------------------------------------------------
# 5. Caches & boot
# ------------------------------------------------------------------
php artisan storage:link || true
php artisan config:cache
php artisan route:cache || true
php artisan view:cache || true

php-fpm -D
exec nginx -g 'daemon off;'
