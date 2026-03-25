#!/bin/bash
clear

read -p "Enter your domain (e.g., panel.example.com): " DOMAIN

# -------------------------------
# VARIABLES
# -------------------------------
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS=$(openssl rand -base64 12)
PANEL_DIR="/var/www/pterodactyl"

# -------------------------------
# DEPENDENCIES
# -------------------------------
apt update && apt install -y \
curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release \
nginx mariadb-server redis-server cron wget zip

# Detect OS
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "ubuntu" ]]; then
    apt install -y software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/sury-php.list
fi

# Redis repo
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis.gpg
echo "deb [signed-by=/usr/share/keyrings/redis.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" \
> /etc/apt/sources.list.d/redis.list

apt update

# -------------------------------
# INSTALL PHP + SERVICES
# -------------------------------
apt install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom}

PHP_VERSION=8.3

# -------------------------------
# COMPOSER
# -------------------------------
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# -------------------------------
# DOWNLOAD PANEL
# -------------------------------
mkdir -p $PANEL_DIR
cd $PANEL_DIR

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# -------------------------------
# DATABASE SETUP
# -------------------------------
mariadb -e "CREATE DATABASE ${DB_NAME};"
mariadb -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

# -------------------------------
# ENV CONFIG
# -------------------------------
cp .env.example .env

sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

echo "APP_ENVIRONMENT_ONLY=false" >> .env

# -------------------------------
# INSTALL PANEL
# -------------------------------
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

php artisan key:generate --force
php artisan migrate --seed --force

# -------------------------------
# PERMISSIONS + CRON
# -------------------------------
chown -R www-data:www-data $PANEL_DIR

(crontab -l 2>/dev/null; echo "* * * * * php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -

# -------------------------------
# NGINX + SSL (SELF-SIGNED)
# -------------------------------
mkdir -p /etc/certs/panel

openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/CN=${DOMAIN}" \
-keyout /etc/certs/panel/privkey.pem \
-out /etc/certs/panel/fullchain.pem

cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root ${PANEL_DIR}/public;
    index index.php;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/ 2>/dev/null

nginx -t && systemctl restart nginx

# -------------------------------
# QUEUE WORKER
# -------------------------------
cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Restart=always
ExecStart=/usr/bin/php ${PANEL_DIR}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable --now redis-server pteroq.service

# -------------------------------
# ADMIN USER
# -------------------------------
php artisan p:user:make

# ===============================
# 🔥 BLUEPRINT INSTALL (MERGED)
# ===============================
cd $PANEL_DIR

wget "$(curl -s https://api.github.com/repos/reviactyl/blueprint/releases/latest \
| grep browser_download_url \
| grep release.zip \
| cut -d '"' -f 4)" -O release.zip

unzip -o release.zip

# Install Node.js 20
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
| gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
> /etc/apt/sources.list.d/nodesource.list

apt update
apt install -y nodejs

npm i -g yarn
yarn install

# Blueprint config
cat > .blueprintrc <<EOF
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF

chmod +x blueprint.sh
bash blueprint.sh

# -------------------------------
# FINAL OUTPUT
# -------------------------------
clear
echo "======================================"
echo "✅ INSTALLATION COMPLETE"
echo "======================================"
echo "🌐 URL: https://${DOMAIN}"
echo "📂 DIR: ${PANEL_DIR}"
echo "👤 DB USER: ${DB_USER}"
echo "🔑 DB PASS: ${DB_PASS}"
echo "======================================"
