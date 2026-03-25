#!/bin/bash

PHP_VERSION="8.3"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

ok(){ echo -e "${GREEN}✔ $1${RESET}"; }
err(){ echo -e "${RED}✖ $1${RESET}"; }
info(){ echo -e "${YELLOW}➜ $1${RESET}"; }

pause(){ read -p "Press Enter to continue..."; }

# ================= INSTALL =================
install_panel() {

read -p "Enter domain (panel.example.com): " DOMAIN
read -p "Enter email for SSL (example@gmail.com): " EMAIL

info "Installing dependencies..."
apt update -y
apt install -y curl nginx mariadb-server redis-server certbot python3-certbot-nginx \
software-properties-common unzip git tar

add-apt-repository -y ppa:ondrej/php
apt update

apt install -y php${PHP_VERSION} php${PHP_VERSION}-{cli,fpm,common,mysql,mbstring,xml,zip,curl,gd,bcmath}

# Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Panel
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz

cp .env.example .env

# DB
DB_PASS=$(openssl rand -base64 12)

mysql -u root <<EOF
CREATE DATABASE panel;
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

sed -i "s|APP_URL=.*|APP_URL=http://${DOMAIN}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

info "Installing panel..."
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan migrate --seed --force

chown -R www-data:www-data /var/www/pterodactyl

# NGINX HTTP FIRST
cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# SSL (REAL AUTO SSL)
info "Requesting SSL certificate..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

if [ $? -eq 0 ]; then
    sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
    ok "SSL installed successfully"
else
    err "SSL failed (check DNS pointing to your server)"
fi

# Queue
cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue
After=redis-server.service

[Service]
User=www-data
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable --now pteroq redis-server

ok "Panel Installed!"
echo "DB Password: $DB_PASS"

pause
}

# ================= USER =================
create_user() {
cd /var/www/pterodactyl || return
php artisan p:user:make
pause
}

# ================= UPDATE =================
update_panel() {
cd /var/www/pterodactyl || return

php artisan down
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz

composer install --no-dev --optimize-autoloader
php artisan migrate --seed --force
php artisan up

ok "Updated!"
pause
}

# ================= UNINSTALL =================
uninstall_panel() {

read -p "Confirm uninstall (y/n): " c
[[ "$c" != "y" ]] && return

rm -rf /var/www/pterodactyl

mysql -u root -e "DROP DATABASE panel;"
mysql -u root -e "DROP USER 'pterodactyl'@'127.0.0.1';"

rm -f /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-available/pterodactyl.conf

systemctl restart nginx

ok "Removed!"
pause
}

# ================= MENU =================
while true; do

clear
echo "Pterodactyl Control"

if [ -d "/var/www/pterodactyl" ]; then
echo "Status: INSTALLED"
else
echo "Status: NOT INSTALLED"
fi

echo ""
echo "1) Install Panel"
echo "2) Create User"
echo "3) Update Panel"
echo "4) Uninstall Panel"
echo "5) Exit"
echo ""

read -p "Select: " ch

case $ch in
1) install_panel ;;
2) create_user ;;
3) update_panel ;;
4) uninstall_panel ;;
5) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac

done
