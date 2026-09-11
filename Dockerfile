FROM node:20-alpine AS assets
WORKDIR /build
COPY package.json ./
RUN npm install
COPY tailwind.config.js ./
COPY src ./src
COPY app/views ./app/views
COPY public ./public
RUN mkdir -p public/assets && npm run build:css

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
COPY --from=assets /build/public/assets/app.css /var/www/html/public/assets/app.css
COPY docker-entrypoint.sh /usr/local/bin/signaldesk-entrypoint

RUN mkdir -p /var/www/html/storage \
    && chmod +x /usr/local/bin/signaldesk-entrypoint \
    && chown -R www-data:www-data /var/www/html/storage

EXPOSE 8080
ENTRYPOINT ["signaldesk-entrypoint"]
