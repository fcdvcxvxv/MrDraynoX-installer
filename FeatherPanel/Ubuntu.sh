# Update the server
apt update && apt upgrade -y
# Add "add-apt-repository" command
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
# Add additional repositories for PHP, Redis, and MariaDB
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
# Update repositories list
apt update
# Add universe repository if you are on Ubuntu 18.04
apt-add-repository universe
# Install Dependencies
apt -y install php8.5 php8.5-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis,mongodb,pgsql,pdo-pgsql} mariadb-server nginx tar unzip zip git redis-server make dos2unix
