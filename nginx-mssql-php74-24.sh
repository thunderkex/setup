#!/bin/bash
# Ubuntu 24.04 only
set -euo pipefail

# Add logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f libldap-2.5-0_2.5.13+dfsg-5_amd64.deb
    rm -f libldap-dev_2.5.13+dfsg-5_amd64.deb
}
trap cleanup EXIT

# Version check
if [[ $(lsb_release -rs) != "24.04" ]]; then
    log "Error: This script is only for Ubuntu 24.04"
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

# Install required LDAP dependencies
sudo apt-fast install -y curl

# Download and install LDAP dependencies
sudo curl -O http://debian.mirror.ac.za/debian/pool/main/o/openldap/libldap-2.5-0_2.5.13+dfsg-5_amd64.deb
sudo curl -O http://debian.mirror.ac.za/debian/pool/main/o/openldap/libldap-dev_2.5.13+dfsg-5_amd64.deb
sudo dpkg -i libldap-2.5-0_2.5.13+dfsg-5_amd64.deb
sudo dpkg -i libldap-dev_2.5.13+dfsg-5_amd64.deb

# Add Microsoft SQL Server repository
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/24.04/mssql-server-2022 noble main" | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

# Clean apt lists and update
sudo rm -rf /var/lib/apt/lists/*
sudo apt-fast update

# Install SQL Server
sudo ACCEPT_EULA=Y apt-fast install -y mssql-server

# Configure SQL Server
log "Configuring SQL Server. Please follow the prompts..."
sudo /opt/mssql/bin/mssql-conf setup

# Verify installation and install tools in one go
if systemctl is-active --quiet mssql-server; then
    log "SQL Server installation completed successfully"
    
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
    
    # Ensure PHP extension directories exist
    sudo mkdir -p /etc/php/7.4/{cli,fpm}/conf.d/
    
    # Install SQL Server extensions
    printf "\n" | sudo pecl install -f sqlsrv
    printf "\n" | sudo pecl install -f pdo_sqlsrv
    
    # Configure extensions for both CLI and FPM
    echo "extension=sqlsrv.so" | sudo tee /etc/php/7.4/cli/conf.d/20-sqlsrv.ini
    echo "extension=pdo_sqlsrv.so" | sudo tee /etc/php/7.4/cli/conf.d/30-pdo_sqlsrv.ini
    echo "extension=sqlsrv.so" | sudo tee /etc/php/7.4/fpm/conf.d/20-sqlsrv.ini
    echo "extension=pdo_sqlsrv.so" | sudo tee /etc/php/7.4/fpm/conf.d/30-pdo_sqlsrv.ini

    # Create symlinks if mods-available directory exists
    if [ -d "/etc/php/7.4/mods-available" ]; then
        echo "extension=sqlsrv.so" | sudo tee /etc/php/7.4/mods-available/sqlsrv.ini
        echo "extension=pdo_sqlsrv.so" | sudo tee /etc/php/7.4/mods-available/pdo_sqlsrv.ini
        sudo phpenmod -v 7.4 sqlsrv pdo_sqlsrv
    fi

    # Verify SQL Server version after install
    if ! /opt/mssql/bin/sqlservr --version | grep -q "2022"; then
        log "Error: SQL Server 2022 installation failed"
        exit 1
    fi

    # Add verification for PHP modules
    if ! php -m | grep -q "sqlsrv"; then
        log "Error: sqlsrv module not installed correctly"
        exit 1
    fi
else
    log "SQL Server installation failed - service not running"
    exit 1
fi

# Restart services
sudo systemctl restart php7.4-fpm
sudo systemctl restart nginx

# Install Nginx UI with proper error handling
if ! curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh | sudo bash -s install; then
    log "Failed to install Nginx UI"
    exit 1
fi