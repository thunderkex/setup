#!/bin/bash

LATEST_MAKE_VERSION="4.4"
CCACHE_SIZE="50G"

# Error handling
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo -e "${GREEN}Detected Ubuntu version: ${UBUNTU_VERSION}${NC}"

# Verify supported version
if (( $(echo "$UBUNTU_VERSION < 20.04" | bc -l) )); then
    echo -e "${RED}Unsupported Ubuntu version. Please use Ubuntu 20.04 or newer.${NC}"
    exit 1
fi

# Install apt-fast for faster package installation
if ! command -v apt-fast &> /dev/null; then
    echo -e "${GREEN}Installing apt-fast...${NC}"
    sudo add-apt-repository -y ppa:apt-fast/stable
    sudo apt update
    echo debconf apt-fast/maxdownloads string 16 | sudo debconf-set-selections
    echo debconf apt-fast/dlflag boolean true | sudo debconf-set-selections
    echo debconf apt-fast/aptmanager string apt | sudo debconf-set-selections
    sudo apt install -y apt-fast
fi

echo -e "${GREEN}Setting up build environment for Android ROM compilation...${NC}"

# Update system
sudo apt-fast update && sudo apt-fast upgrade -y

# Define base packages
BASE_PACKAGES="git ccache automake lzop bison gperf build-essential zip curl \
    zlib1g-dev g++-multilib libxml2-utils bzip2 libbz2-dev libbz2-1.0 \
    libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool \
    make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom \
    libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 libx11-dev \
    libgl1-mesa-dev xsltproc unzip device-tree-compiler ninja-build lib32z1 lib32stdc++6"

# Version specific packages
if (( $(echo "$UBUNTU_VERSION >= 22.04" | bc -l) )); then
    # Ubuntu 22.04 and newer
    PACKAGES="$BASE_PACKAGES libncurses5-dev python-is-python3 python3-pip lib32ncurses6"
elif (( $(echo "$UBUNTU_VERSION >= 20.04" | bc -l) )); then
    # Ubuntu 20.04
    PACKAGES="$BASE_PACKAGES libncurses5-dev python python3-pip lib32ncurses6"
fi

# Install packages
sudo apt-fast install -y $PACKAGES

# Install Java based on Ubuntu version
if (( $(echo "$UBUNTU_VERSION >= 22.04" | bc -l) )); then
    sudo apt-fast install -y openjdk-11-jdk openjdk-17-jdk
else
    sudo apt-fast install -y openjdk-11-jdk
    # For Ubuntu 20.04, manually install Java 17 if needed
    if ! command -v java-17 &> /dev/null; then
        sudo add-apt-repository -y ppa:openjdk-r/ppa
        sudo apt-fast update
        sudo apt-fast install -y openjdk-17-jdk
    fi
fi

sudo update-alternatives --config java

# Setup ccache
echo -e "${GREEN}Setting up ccache...${NC}"
ccache -M "${CCACHE_SIZE}"
echo 'export USE_CCACHE=1' >> ~/.bashrc
echo 'export CCACHE_EXEC=/usr/bin/ccache' >> ~/.bashrc
echo 'export CCACHE_DIR="${HOME}/.ccache"' >> ~/.bashrc

# Setup git
echo -e "${GREEN}Configuring git...${NC}"
git config --global color.ui true

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${GREEN}Installing GitHub CLI...${NC}"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-fast update
    sudo apt-fast install -y gh
fi

# Install repo tool
if ! command -v repo &> /dev/null; then
    echo -e "${GREEN}Installing repo tool...${NC}"
    sudo curl --create-dirs -L -o /usr/local/bin/repo -O -L https://storage.googleapis.com/git-repo-downloads/repo
    sudo chmod a+rx /usr/local/bin/repo
fi

# Setup Android udev rules
echo -e "${GREEN}Setting up Android udev rules...${NC}"
sudo curl --create-dirs -L -o /etc/udev/rules.d/51-android.rules -O -L https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/51-android.rules
sudo chmod 644 /etc/udev/rules.d/51-android.rules
sudo chown root /etc/udev/rules.d/51-android.rules
sudo systemctl restart udev

# Optimize system for building
echo -e "${GREEN}Optimizing system for building...${NC}"
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Setup memory management for better build performance
echo -e "${GREEN}Setting up memory management...${NC}"
sudo sysctl -w vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Create build directory
echo -e "${GREEN}Creating build directory...${NC}"
mkdir -p ~/android/rom

# Final setup message
echo -e "${GREEN}Setup completed! Some important notes:${NC}"
echo "1. Use 'repo init -u <manifest_url> -b <branch>' to initialize your ROM repository"
echo "2. Use 'repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags' to sync sources"
echo "3. Make sure to source build/envsetup.sh before building"
echo "4. Ensure you have at least 200GB of free space"
echo "5. RAM requirements: minimum 16GB recommended"
echo "6. Detected Ubuntu version: ${UBUNTU_VERSION}"
