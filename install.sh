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

phpkg_version="v2.2.2"

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
                sudo apt install -y php php-mbstring php-curl php-zip
                ;;
            fedora)
                echo "Detected Fedora"
                sudo dnf install -y php php-mbstring php-curl php-zip
                ;;
            arch)
                echo "Detected Arch Linux"
                sudo pacman -Syu --noconfirm
                sudo pacman -S --noconfirm php php-mbstring php-curl php-zip
                ;;
            alpine)
                echo "Detected Alpine Linux"
                apk update
                apk add php php-mbstring php-curl php-zip
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
        # mbstring is usually included with Homebrew PHP, but verify
    else
        echo "Unsupported or unrecognized OS. Please install PHP manually. Make sure php-mbstring, php-curl and php-zip are enabled in modules."
        exit 1
    fi
fi

# Verify PHP extensions are available
echo "Checking required PHP extensions..."
if ! php -m | grep -q mbstring; then
    echo -e "${YELLOW}Warning: mbstring extension is not loaded. Attempting to install...${DEFAULT_COLOR}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        
        case "$OS" in
            ubuntu|debian)
                sudo apt install -y php-mbstring
                ;;
            fedora)
                sudo dnf install -y php-mbstring
                ;;
            arch)
                sudo pacman -S --noconfirm php-mbstring
                ;;
            alpine)
                apk add php-mbstring
                ;;
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, mbstring should be included, but if not, reinstall PHP
        echo "mbstring should be included with Homebrew PHP. If this persists, try: brew reinstall php"
    fi
fi

if ! php -m | grep -q mbstring; then
    echo -e "${RED}Error: mbstring extension is required but could not be installed. Please install it manually.${DEFAULT_COLOR}"
    exit 1
fi

PHP_VERSION=$(php -r 'echo PHP_VERSION;')

if [[ "$(printf '%s\n' "8.1" "$PHP_VERSION" | sort -V | head -n1)" == "8.1" ]]
then
    echo -e "${GREEN}PHP ${PHP_VERSION} detected${DEFAULT_COLOR}"
else
    echo -e "${RED}Required PHP version not detected! Detected version: PHP ${PHP_VERSION}. phpkg needs PHP >= 8.1.${DEFAULT_COLOR}"
    exit 1
fi

# Check if this is an update or fresh install
if [ -d "$root_path" ]; then
    echo -e "Updating phpkg to version: ${GREEN}${phpkg_version}${DEFAULT_COLOR} ..."
    echo "Existing installation found at: $root_path"
    is_update=true
else
    echo -e "Installing phpkg version: ${GREEN}${phpkg_version}${DEFAULT_COLOR} ..."
    is_update=false
fi

echo -e "Downloading phpkg"
curl -s -L "https://github.com/php-repos/phpkg/releases/download/$phpkg_version/phpkg.zip" -o "$temp_path/phpkg.zip"

echo -e "${GREEN}Download finished${DEFAULT_COLOR}"

echo "Setting up..."

# Preserve credentials.json if it exists (user may have configured it)
existing_credentials=""
if [ "$is_update" = true ] && [ -f "$root_path/credentials.json" ]; then
    echo "Preserving existing credentials.json..."
    existing_credentials=$(cat "$root_path/credentials.json")
fi

rm -fR "$root_path"
unzip -q -o "$temp_path"/phpkg.zip -d "$temp_path"
mv "$temp_path"/production "$root_path"

# Restore existing credentials if we had them, otherwise create from example
if [ -n "$existing_credentials" ]; then
    echo "Restoring existing credentials.json..."
    echo "$existing_credentials" > "$root_path/credentials.json"
else
    echo "Creating credentials.json from example..."
    cp "$root_path"/credentials.example.json "$root_path"/credentials.json
fi

DEFAULT_SHELL=$(echo "$SHELL")

EXPORT_PATH="export PATH=\"\$PATH:$root_path\""

eval $EXPORT_PATH

# Add to initialization file based on shell (only if not already present)
if echo "$DEFAULT_SHELL" | grep -q "zsh"; then
    if ! grep -q "$root_path" "$HOME/.zshrc" 2>/dev/null; then
        echo "Add phpkg to zsh"
        echo "$EXPORT_PATH" >> "$HOME/.zshrc"
    else
        echo "phpkg is already in your zsh configuration"
    fi
elif echo "$DEFAULT_SHELL" | grep -q "bash"; then
    if ! grep -q "$root_path" "$HOME/.bashrc" 2>/dev/null; then
        echo "Add phpkg to bash"
        echo "$EXPORT_PATH" >> "$HOME/.bashrc"
    else
        echo "phpkg is already in your bash configuration"
    fi
elif echo "$DEFAULT_SHELL" | grep -q "sh"; then
    if ! grep -q "$root_path" "$HOME/.profile" 2>/dev/null; then
        echo "Add phpkg to sh"
        echo "$EXPORT_PATH" >> "$HOME/.profile"  # Use .profile for sh in Alpine
    else
        echo "phpkg is already in your profile"
    fi
else
    echo "Unsupported shell detected: $DEFAULT_SHELL"
    if ! grep -q "$root_path" "$HOME/.profile" 2>/dev/null; then
        echo "$EXPORT_PATH" >> "$HOME/.profile"  # Fallback to .profile for unsupported shells
    fi
fi

if [ "$is_update" = true ]; then
    echo -e "\n${GREEN}Update finished successfully! phpkg has been updated to version ${phpkg_version}.${DEFAULT_COLOR}"
else
    echo -e "\n${GREEN}Installation finished successfully. Enjoy.${DEFAULT_COLOR}"
fi
echo ""
echo "To update phpkg in the future, simply run this installation script again."
