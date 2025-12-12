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

# Load configuration from config.json with fallback values
# Try to find config.json in the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
CONFIG_FILE=""
TEMP_CONFIG_FILE=""

# Fallback values (used when config.json is not available)
FALLBACK_PHPKG_VERSION="v2.2.2"
FALLBACK_PHP_MIN_VERSION="8.1"
FALLBACK_PHP_EXTENSIONS="mbstring curl zip"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/config.json" ]; then
    # Config file exists in the same directory as the script
    CONFIG_FILE="$SCRIPT_DIR/config.json"
else
    # If running from curl or config.json not found, try to download it from the repository
    TEMP_CONFIG_FILE=$(mktemp)
    if curl -s -L "https://raw.github.com/php-repos/phpkg-installation/master/config.json" -o "$TEMP_CONFIG_FILE" 2>/dev/null && [ -f "$TEMP_CONFIG_FILE" ] && [ -s "$TEMP_CONFIG_FILE" ]; then
        CONFIG_FILE="$TEMP_CONFIG_FILE"
    else
        # Config file not available, use fallback values
        CONFIG_FILE=""
        rm -f "$TEMP_CONFIG_FILE" 2>/dev/null
    fi
fi

# Parse config.json if available, otherwise use fallback values
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    phpkg_version=$(grep -o '"phpkg_version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
    php_min_version=$(grep -o '"php_min_version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
    php_extensions=$(grep -o '"php_extensions"[[:space:]]*:\[[^]]*\]' "$CONFIG_FILE" | grep -o '"[^"]*"' | sed 's/"//g' | tr '\n' ' ')
    
    # Use fallback if parsing failed
    if [ -z "$phpkg_version" ] || [ -z "$php_min_version" ]; then
        phpkg_version="$FALLBACK_PHPKG_VERSION"
        php_min_version="$FALLBACK_PHP_MIN_VERSION"
        php_extensions="$FALLBACK_PHP_EXTENSIONS"
    fi
else
    # Use fallback values
    phpkg_version="$FALLBACK_PHPKG_VERSION"
    php_min_version="$FALLBACK_PHP_MIN_VERSION"
    php_extensions="$FALLBACK_PHP_EXTENSIONS"
fi

# Cleanup temp config file if we downloaded it
if [ -n "$TEMP_CONFIG_FILE" ] && [ -f "$TEMP_CONFIG_FILE" ]; then
    rm -f "$TEMP_CONFIG_FILE" 2>/dev/null
fi

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
        echo "Unsupported or unrecognized OS. Please install PHP manually. Make sure the following PHP extensions are enabled:"
        for ext in $php_extensions; do
            echo "  - php-${ext}"
        done
        exit 1
    fi
fi

# Verify PHP extensions are available
echo "Checking required PHP extensions..."
missing_extensions=""
for ext in $php_extensions; do
    if ! php -m | grep -q "^${ext}$"; then
        echo -e "${YELLOW}Warning: ${ext} extension is not loaded. Attempting to install...${DEFAULT_COLOR}"
        missing_extensions="$missing_extensions $ext"
        
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            
            case "$OS" in
                ubuntu|debian)
                    sudo apt install -y "php-${ext}"
                    ;;
                fedora)
                    sudo dnf install -y "php-${ext}"
                    ;;
                arch)
                    sudo pacman -S --noconfirm "php-${ext}"
                    ;;
                alpine)
                    apk add "php-${ext}"
                    ;;
            esac
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # On macOS, extensions should be included, but if not, reinstall PHP
            echo "${ext} should be included with Homebrew PHP. If this persists, try: brew reinstall php"
        fi
    fi
done

# Verify all extensions are now loaded
for ext in $php_extensions; do
    if ! php -m | grep -q "^${ext}$"; then
        echo -e "${RED}Error: ${ext} extension is required but could not be installed. Please install it manually.${DEFAULT_COLOR}"
        exit 1
    fi
done

PHP_VERSION=$(php -r 'echo PHP_VERSION;')

if [[ "$(printf '%s\n' "$php_min_version" "$PHP_VERSION" | sort -V | head -n1)" == "$php_min_version" ]]
then
    echo -e "${GREEN}PHP ${PHP_VERSION} detected${DEFAULT_COLOR}"
else
    echo -e "${RED}Required PHP version not detected! Detected version: PHP ${PHP_VERSION}. phpkg needs PHP >= ${php_min_version}.${DEFAULT_COLOR}"
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
