#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
DEFAULT_COLOR='\033[0m' # No Color

USER=${USER:-$(id -u -n)}
HOME="${HOME:-$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)}"
HOME="${HOME:-$(eval echo ~"$USER")}"

temp_path=$(mktemp -d)

root_path=$HOME/.phpkg

phpkg_version="v2.2.1"

# Check if PHP is installed
if ! command -v php &> /dev/null
then
    echo "PHP is not installed"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID

        case "$OS" in
            ubuntu|debian)
                echo "Detected Ubuntu/Debian"
                sudo apt install -y php
                ;;
            fedora)
                echo "Detected Fedora"
                sudo dnf install -y php
                ;;
            arch)
                echo "Detected Arch Linux"
                sudo pacman -Syu --noconfirm
                sudo pacman -S --noconfirm php
                ;;
            alpine)
                echo "Detected Alpine Linux"
                apk update
                apk add php
                ;;
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Detected macOS"
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Installing Homebrew first."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew update
        brew install php
    else
        echo "Unsupported or unrecognized OS. Please install PHP manually. Make sure php-curl and php-unzip are enabled in modules."
        exit 1
    fi
fi

PHP_VERSION=$(php -r 'echo PHP_VERSION;')

if [[ "$(printf '%s\n' "8.1" "$PHP_VERSION" | sort -V | head -n1)" == "8.1" ]]
then
    echo -e "${GREEN}PHP ${PHP_VERSION} detected${DEFAULT_COLOR}"
else
    echo -e "${RED}Required PHP version not detected! Detected version: PHP ${PHP_VERSION}. phpkg needs PHP >= 8.1.${DEFAULT_COLOR}"
    exit 1
fi

echo -e "Installing phpkg version: ${GREEN}${phpkg_version}${DEFAULT_COLOR} ..."
echo -e "Downloading phpkg"
curl -s -L "https://github.com/php-repos/phpkg/releases/download/$phpkg_version/phpkg.zip" -o "$temp_path/phpkg.zip"

echo -e "${GREEN}Download finished${DEFAULT_COLOR}"

echo "Setting up..."
rm -fR "$root_path"
unzip -q -o "$temp_path"/phpkg.zip -d "$temp_path"
mv "$temp_path"/production "$root_path"

echo "Make credential file"
cp "$root_path"/credentials.example.json "$root_path"/credentials.json

DEFAULT_SHELL=$(echo "$SHELL")

EXPORT_PATH="export PATH=\"\$PATH:$root_path\""

eval $EXPORT_PATH

# Add to initialization file based on shell
if echo "$DEFAULT_SHELL" | grep -q "zsh"; then
    echo "Add phpkg to zsh"
    echo "$EXPORT_PATH" >> "$HOME/.zshrc"
elif echo "$DEFAULT_SHELL" | grep -q "bash"; then
    echo "Add phpkg to bash"
    echo "$EXPORT_PATH" >> "$HOME/.bashrc"
elif echo "$DEFAULT_SHELL" | grep -q "sh"; then
    echo "Add phpkg to sh"
    echo "$EXPORT_PATH" >> "$HOME/.profile"  # Use .profile for sh in Alpine
else
    echo "Unsupported shell detected: $DEFAULT_SHELL"
    echo "$EXPORT_PATH" >> "$HOME/.profile"  # Fallback to .profile for unsupported shells
fi

echo -e "\n${GREEN}Installation finished successfully. Enjoy.${DEFAULT_COLOR}"
