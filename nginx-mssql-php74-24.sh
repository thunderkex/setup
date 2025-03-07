#!/bin/bash
# Ubuntu 24.04 only
set -e

# Check and install apt-fast if not present
if ! command -v apt-fast &> /dev/null; then
    sudo add-apt-repository -y ppa:apt-fast/stable
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apt-fast
fi

# Install necessary dependencies
sudo apt-fast update
sudo apt-fast install -y software-properties-common curl nginx

# Add PHP repository and install PHP 7.4
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-fast update
sudo apt-fast install -y \
    php7.4-fpm \
    php7.4-cli \
    php7.4-common \
    php7.4-mbstring \
    php-pear \
    php7.4-dev \
    php7.4-curl \
    php7.4-gd \
    php7.4-zip \
    php7.4-xml \
    php7.4-bcmath \
    php7.4-intl

# Install MSSQL Server
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/24.04/mssql-server-2022.list)"
sudo apt-fast update
sudo apt-fast install -y mssql-server
sudo /opt/mssql/bin/mssql-conf setup

# Add Microsoft repository and install MS SQL tools
curl -s https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
sudo bash -c "curl -s https://packages.microsoft.com/config/ubuntu/24.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
sudo apt-fast update
sudo ACCEPT_EULA=Y apt-fast install -y msodbcsql18 mssql-tools18 unixodbc-dev

# Add MS SQL tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc

# Install PHP extensions for SQL Server
sudo pecl channel-update pecl.php.net
sudo update-alternatives --set php /usr/bin/php7.4
sudo update-alternatives --set php-config /usr/bin/php-config7.4
sudo update-alternatives --set phpize /usr/bin/phpize7.4
sudo pecl install -f sqlsrv
sudo pecl install -f pdo_sqlsrv

# Configure PHP extensions
sudo bash -c 'echo "extension=sqlsrv.so" > /etc/php/7.4/mods-available/sqlsrv.ini'
sudo bash -c 'echo "extension=pdo_sqlsrv.so" > /etc/php/7.4/mods-available/pdo_sqlsrv.ini'
sudo phpenmod -v 7.4 sqlsrv pdo_sqlsrv

# Restart services
sudo systemctl restart php7.4-fpm
sudo systemctl restart nginx

# Install Nginx UI
sudo bash <(curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh) install