FROM php:8.2-apache
RUN docker-php-ext-install pdo_pgsql curl && a2enmod rewrite
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
COPY . /var/www/html
COPY docker-entrypoint.sh /usr/local/bin/signaldesk-entrypoint
RUN chmod +x /usr/local/bin/signaldesk-entrypoint && chown -R www-data:www-data /var/www/html/storage
EXPOSE 8080
ENTRYPOINT ["signaldesk-entrypoint"]
