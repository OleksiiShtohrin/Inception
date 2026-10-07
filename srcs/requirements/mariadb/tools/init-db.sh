#!/bin/bash

set -e

DATA_DIR="/var/lib/mysql"
INIT_MARKER="$DATA_DIR/.inception_initialized"

DB_NAME="${MYSQL_DATABASE}"
DB_USER="${MYSQL_USER}"

ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -f "$INIT_MARKER" ]; then
    echo "Initializing MariaDB..."

    mariadbd \
        --user=mysql \
        --skip-networking \
        --socket=/run/mysqld/mysqld.sock \
        &

    TEMP_SERVER_PID=$!

    echo "Waiting for MariaDB..."

    until mariadb-admin ping --socket=/run/mysqld/mysqld.sock --silent; do
        sleep 1
    done

    echo "MariaDB is ready."

    mariadb --socket=/run/mysqld/mysqld.sock -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS ${DB_NAME};

CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
EOF

    touch "$INIT_MARKER"

    echo "MariaDB initialization completed."

    mariadb-admin \
        --socket=/run/mysqld/mysqld.sock \
        -u root \
        -p"${ROOT_PASSWORD}" \
        shutdown

    wait "$TEMP_SERVER_PID"
fi

echo "Starting MariaDB..."

exec mariadbd --user=mysql --console