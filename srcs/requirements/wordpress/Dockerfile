FROM debian:12

ARG WORDPRESS_VERSION=7.1.2
ARG WP_CLI_VERSION=2.12.0

RUN apt-get update && apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-redis \
    php8.2-curl \
    php8.2-gd \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-intl \
    mariadb-client \
    curl \
    ca-certificates \
    tar \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/wordpress \
    && curl -fsSL \
    "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
    -o /tmp/wordpress.tar.gz \
    && tar -xzf /tmp/wordpress.tar.gz \
    --strip-components=1 \
    -C /usr/src/wordpress \
    && rm /tmp/wordpress.tar.gz

RUN curl -fsSL \
    "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

RUN curl -fsSL \
    "https://downloads.wordpress.org/plugin/redis-cache.3.0.0.zip" \
    -o /tmp/redis-cache.zip \
    && unzip /tmp/redis-cache.zip -d /usr/src/wordpress/wp-content/plugins/ \
    && rm /tmp/redis-cache.zip

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init-wp.sh /usr/local/bin/init-wp.sh

RUN chmod +x /usr/local/bin/init-wp.sh

CMD ["/usr/local/bin/init-wp.sh"]