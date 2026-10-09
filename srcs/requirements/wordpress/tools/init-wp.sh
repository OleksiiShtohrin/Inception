#!/bin/bash

set -e

WP_DIR="/var/www/html"
WP_SOURCE="/usr/src/wordpress"

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

if [ ! -f "$WP_DIR/wp-includes/version.php" ]; then
    echo "Initializing WordPress files..."

    mkdir -p "$WP_DIR"

    cp -a "$WP_SOURCE/." "$WP_DIR/"
    chown -R www-data:www-data "$WP_DIR"

    echo "WordPress files copied."
else
    echo "WordPress files already exist."
fi

echo "Checking Redis Object Cache plugin..."

if [ ! -d "$WP_DIR/wp-content/plugins/redis-cache" ]; then
    cp -a "$WP_SOURCE/wp-content/plugins/redis-cache" \
        "$WP_DIR/wp-content/plugins/"
fi

chown -R www-data:www-data \
    "$WP_DIR/wp-content/plugins/redis-cache"

echo "Redis Object Cache plugin is ready."

if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --path="$WP_DIR" \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$MYSQL_HOST:$MYSQL_PORT" \
        --allow-root

    chown www-data:www-data "$WP_DIR/wp-config.php"

    echo "wp-config.php created."
else
    echo "wp-config.php already exists."
fi

echo "Configuring database host..."

wp config set DB_HOST "$MYSQL_HOST:$MYSQL_PORT" \
    --path="$WP_DIR" \
    --type=constant \
    --allow-root

echo "Database host configured: $MYSQL_HOST:$MYSQL_PORT"

echo "Configuring Redis..."

wp config set WP_REDIS_HOST redis \
    --path="$WP_DIR" \
    --type=constant \
    --allow-root

wp config set WP_REDIS_PORT 6379 \
    --path="$WP_DIR" \
    --type=constant \
    --allow-root

echo "Redis configuration completed."

echo "Checking MariaDB connection..."

DB_READY=0

for i in {1..30}; do
    if wp db check \
        --path="$WP_DIR" \
        --allow-root >/dev/null 2>&1
    then
        DB_READY=1
        break
    fi

    echo "Waiting for MariaDB... ($i/30)"
    sleep 1
done

if [ "$DB_READY" -ne 1 ]; then
    echo "ERROR: MariaDB is not ready."
    exit 1
fi

echo "MariaDB is ready."

if ! wp core is-installed \
    --path="$WP_DIR" \
    --allow-root >/dev/null 2>&1
then
    echo "Installing WordPress..."

    wp core install \
        --path="$WP_DIR" \
        --url="$DOMAIN_NAME" \
        --title="Inception WordPress" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root

    echo "WordPress installed."

    echo "Creating WordPress user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=subscriber \
        --path="$WP_DIR" \
        --allow-root

    echo "WordPress user created."
else
    echo "WordPress is already installed."
fi

echo "Activating Redis Object Cache..."

wp plugin activate redis-cache \
    --path="$WP_DIR" \
    --allow-root

echo "Redis Object Cache plugin activated."

echo "Enabling Redis Object Cache..."

wp redis enable \
    --path="$WP_DIR" \
    --allow-root

echo "Redis Object Cache enabled."

echo "Starting PHP-FPM..."

exec php-fpm8.2 -F
