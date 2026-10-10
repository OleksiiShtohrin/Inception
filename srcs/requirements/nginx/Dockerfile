FROM debian:12

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    adminer \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/adminer \
    && cp -a /usr/share/adminer/adminer/. /var/www/adminer/

COPY conf/nginx.conf /etc/nginx/nginx.conf

COPY tools/init-nginx.sh /usr/local/bin/init-nginx.sh

RUN chmod +x /usr/local/bin/init-nginx.sh

CMD ["/usr/local/bin/init-nginx.sh"]