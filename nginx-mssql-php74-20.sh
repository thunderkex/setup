#!/bin/bash
# Ubuntu 20.04 only
set -euo pipefail

# Add logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Version check
if [[ $(lsb_release -rs) != "20.04" ]]; then
    log "Error: This script is only for Ubuntu 20.04"
    exit 1
fi

# Check and install apt-fast if not present
if ! command -v apt-fast &> /dev/null; then
    sudo add-apt-repository -y ppa:apt-fast/stable
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apt-fast
fi

# Install necessary dependencies
sudo apt-fast update
sudo apt-fast install -y software-properties-common curl nginx

# Install MSSQL Server
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
sudo apt-fast update
sudo apt-fast install -y mssql-server
sudo /opt/mssql/bin/mssql-conf setup

# Add PHP repository and install PHP 7.4
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-fast update
sudo apt-fast install -y \
    php7.4-fpm \
    php7.4-cli \
    php7.4-mbstring \
    php-pear \
    php7.4-dev \
    php7.4-curl \
    php7.4-gd \
    php7.4-zip \
    php7.4-xml

# Add Microsoft repository and install MS SQL tools
curl -s https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo bash -c "curl -s https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
sudo apt-fast update
sudo ACCEPT_EULA=Y apt-fast -y install msodbcsql17 mssql-tools unixodbc-dev

# Add MS SQL tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

# Install PHP extensions for SQL Server
sudo update-alternatives --set php /usr/bin/php7.4
sudo update-alternatives --set php-config /usr/bin/php-config7.4
sudo update-alternatives --set phpize /usr/bin/phpize7.4
sudo pecl install -f sqlsrv
sudo pecl install -f pdo_sqlsrv
sudo phpenmod -v 7.4 sqlsrv pdo_sqlsrv

# Restart PHP-FPM service
sudo systemctl restart php7.4-fpm

# Install Nginx UI
sudo bash <(curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh) install

# Add installation verification
verify_services() {
    local services=("nginx" "php7.4-fpm" "mssql-server")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            log "Error: $service is not running"
            exit 1
        fi
    done
}

verify_services