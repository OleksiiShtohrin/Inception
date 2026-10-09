#!/bin/bash

set -eu

SECRETS_DIR="secrets"

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

create_secret() {
    local file="$1"

    if [ -f "$file" ]; then
        echo "Keeping existing secret: $file"
        return
    fi

    openssl rand -hex 6 > "$file"
    chmod 600 "$file"

    echo "Created secret: $file"
}

create_secret "$SECRETS_DIR/db_password.txt"
create_secret "$SECRETS_DIR/db_root_password.txt"
create_secret "$SECRETS_DIR/wp_admin_password.txt"
create_secret "$SECRETS_DIR/wp_user_password.txt"

echo "Secrets are ready."
