#!/bin/bash

set -e

mkdir -p /var/run/vsftpd/empty
chmod 555 /var/run/vsftpd/empty

FTP_USER="ftpuser"
FTP_PASSWORD_FILE="/run/secrets/ftp_password"

if [ ! -s "$FTP_PASSWORD_FILE" ]; then
    echo "ERROR: FTP password secret is missing or empty."
    exit 1
fi

if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -o -u 33 -g 33 -d /var/www/html -s /bin/bash "$FTP_USER"
fi

echo "$FTP_USER:$(cat "$FTP_PASSWORD_FILE")" | chpasswd

echo "Starting FTP server..."
exec /usr/sbin/vsftpd /etc/vsftpd.conf