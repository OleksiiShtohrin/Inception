#!/bin/bash

set -eu

ENV_FILE="srcs/.env"
ENV_EXAMPLE="srcs/.env.example"
SECRETS_DIR="secrets"

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

# Check the environment configuration file.
if [ ! -f "$ENV_FILE" ]; then
    fail "Missing $ENV_FILE. Create it manually from $ENV_EXAMPLE."
fi

if [ ! -r "$ENV_FILE" ]; then
    fail "$ENV_FILE exists but cannot be read."
fi

# Check that every required variable exists and has a value.
required_vars="
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
WP_ADMIN_USER
WP_ADMIN_EMAIL
WP_USER
WP_USER_EMAIL
MYSQL_HOST
MYSQL_PORT
"

for var in $required_vars; do
    if ! awk -F= -v key="$var" '
        /^[[:space:]]*#/ { next }
        {
            name = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)

            if (name == key) {
                value = substr($0, index($0, "=") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

                if (value != "")
                    found = 1
            }
        }
        END { exit !found }
    ' "$ENV_FILE"; then
        fail "Missing or empty variable '$var' in $ENV_FILE."
    fi
done

# Check the secrets directory.
if [ ! -d "$SECRETS_DIR" ]; then
    fail "Missing $SECRETS_DIR/. Create the secrets manually or run: bash scripts/create-secrets.sh"
fi

# Check all required secret files.
for secret in \
    db_password.txt \
    db_root_password.txt \
    wp_admin_password.txt \
    wp_user_password.txt \
    ftp_password.txt
do
    file="$SECRETS_DIR/$secret"

    if [ ! -f "$file" ]; then
        fail "Missing secret $file. Restore it manually or run: bash scripts/create-secrets.sh"
    fi

    if [ ! -s "$file" ]; then
        fail "Secret $file is empty. Restore it manually or run: bash scripts/create-secrets.sh"
    fi

    if [ ! -r "$file" ]; then
        fail "Secret $file cannot be read. Check its permissions."
    fi
done

echo "Configuration check passed."
