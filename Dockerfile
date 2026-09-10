FROM php:8.2-apache-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev libpq5 libcurl4 libcurl4-openssl-dev \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql curl \
    && a2enmod rewrite \
    && apt-get purge -y --auto-remove libpq-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

COPY . /var/www/html
COPY docker-entrypoint.sh /usr/local/bin/signaldesk-entrypoint

RUN chmod +x /usr/local/bin/signaldesk-entrypoint \
    && chown -R www-data:www-data /var/www/html/storage

EXPOSE 8080
ENTRYPOINT ["signaldesk-entrypoint"]
