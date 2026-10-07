#!/bin/bash

set -e

SSL_DIR="/etc/nginx/ssl"

mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/nginx.crt" ] || [ ! -f "$SSL_DIR/nginx.key" ]; then
    echo "Generating self-signed TLS certificate..."

    openssl req -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 365 \
        -keyout "$SSL_DIR/nginx.key" \
        -out "$SSL_DIR/nginx.crt" \
        -subj "/C=ES/ST=Spain/L=Bilbao/O=42/OU=Inception/CN=oshtohri.42.fr"

    chmod 600 "$SSL_DIR/nginx.key"
    chmod 644 "$SSL_DIR/nginx.crt"

    echo "TLS certificate generated."
else
    echo "TLS certificate already exists."
fi

echo "Starting NGINX..."

exec nginx -g "daemon off;"