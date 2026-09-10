#!/bin/sh
set -eu
if [ "$#" -gt 0 ]; then exec "$@"; fi
PORT="${PORT:-8080}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf
cat >> /etc/apache2/conf-available/zz-signaldesk-proxy.conf <<'EOF'
# Render terminates TLS and forwards the public request to Apache. Keep
# redirects relative/public instead of exposing the internal container port.
UseCanonicalName Off
UseCanonicalPhysicalPort Off
EOF
 a2enconf zz-signaldesk-proxy >/dev/null
cat >> /etc/apache2/sites-available/000-default.conf <<'EOF'
<Directory /var/www/html/public>
    AllowOverride All
    Require all granted
    DirectoryIndex index.php
    DirectorySlash Off
</Directory>
EOF
exec apache2-foreground
