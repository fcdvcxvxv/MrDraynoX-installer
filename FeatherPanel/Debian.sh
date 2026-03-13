# Update the server
apt update && apt upgrade -y
# Install necessary packages
apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release make

# Add additional repositories for PHP, Redis, and MariaDB
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
curl -fsSL https://packages.sury.org/php/ apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

# Update repositories list
apt update

# Install PHP and required extensions
apt install -y php8.5 php8.5-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,redis,mongodb,pgsql,pdo-pgsql}

# MariaDB repo setup script
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash

# Install the rest of dependencies
apt install -y mariadb-server nginx tar unzip git redis-server zip dos2unix
