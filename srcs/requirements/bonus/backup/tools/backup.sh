#!/bin/bash

set -eu

DB_HOST="${MYSQL_HOST:-mariadb}"
DB_PORT="${MYSQL_PORT:-3306}"
DB_NAME="${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
DB_USER="${MYSQL_USER:?MYSQL_USER is required}"
DB_PASSWORD_FILE="/run/secrets/db_password"
BACKUP_DIR="/backups"

if [ ! -s "$DB_PASSWORD_FILE" ]; then
    echo "ERROR: Database password secret is missing or empty." >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"

echo "Waiting for MariaDB..."

until mariadb-admin ping \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --password="$(cat "$DB_PASSWORD_FILE")" \
    --silent
do
    sleep 2
done

echo "Creating database backup..."

if mariadb-dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --password="$(cat "$DB_PASSWORD_FILE")" \
    --single-transaction \
    --routines \
    --triggers \
    "$DB_NAME" > "$BACKUP_FILE"
then
    chmod 600 "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
else
    rm -f "$BACKUP_FILE"
    echo "ERROR: Database backup failed." >&2
    exit 1
fi

