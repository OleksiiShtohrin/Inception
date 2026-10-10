FROM debian:12

RUN apt-get update && apt-get install -y \
    adminer \
    php8.2-fpm \
    php8.2-mysql \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/adminer \
    && cp -a /usr/share/adminer/adminer/. /var/www/adminer/ \
    && chown -R www-data:www-data /var/www/adminer

RUN sed -i 's|^listen = .*|listen = 9000|' \
    /etc/php/8.2/fpm/pool.d/www.conf

CMD ["php-fpm8.2", "-F"]
