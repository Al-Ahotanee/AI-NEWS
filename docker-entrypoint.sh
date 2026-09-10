#!/bin/sh
set -eu
if [ "$#" -gt 0 ]; then exec "$@"; fi
PORT="${PORT:-8080}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf
cat >> /etc/apache2/sites-available/000-default.conf <<'EOF'
<Directory /var/www/html/public>
    AllowOverride All
    Require all granted
</Directory>
EOF
exec apache2-foreground
