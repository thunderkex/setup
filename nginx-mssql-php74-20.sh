#!/bin/bash
# Ubuntu 20.04 only
# Install necessary dependencies
sudo apt-get update
sudo apt-get install -y software-properties-common curl
sudo apt install nginx
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
sudo apt-get update
sudo apt-get install -y mssql-server
sudo /opt/mssql/bin/mssql-conf setup
# Add PHP repository and install PHP 7.4 (since PHP 7.0 is not available for Ubuntu 20.04)
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php7.4-fpm php7.4-cli php7.4-mbstring php-pear php7.4-dev php7.4-curl php7.4-gd php7.4-zip php7.4-xml

# Add Microsoft repository and install MS SQL tools
curl -s https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo bash -c "curl -s https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list"
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get -y install msodbcsql17 mssql-tools unixodbc-dev

# Add MS SQL tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

# Install PHP extensions for SQL Server
sudo apt install php7.4-dev
sudo update-alternatives --set php /usr/bin/php7.4
sudo update-alternatives --set php-config /usr/bin/php-config7.4
sudo update-alternatives --set phpize /usr/bin/phpize7.4
sudo pecl install -f sqlsrv
sudo pecl install -f pdo_sqlsrv
sudo phpenmod -v 7.4 sqlsrv pdo_sqlsrv

# Restart PHP-FPM service
sudo systemctl restart php7.4-fpm

sudo bash <(curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh) install