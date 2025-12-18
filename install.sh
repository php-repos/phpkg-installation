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

# PHP command wrapper - will be set to actual PHP binary if needed
PHP_CMD="php"

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
    if curl -s -L "https://raw.githubusercontent.com/php-repos/phpkg-installation/master/config.json" -o "$TEMP_CONFIG_FILE" 2>/dev/null && [ -f "$TEMP_CONFIG_FILE" ] && [ -s "$TEMP_CONFIG_FILE" ]; then
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
# On Alpine, PHP might be installed as php83, php82, etc.
if ! command -v php &> /dev/null; then
    # Check for versioned PHP binaries (Alpine Linux)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "alpine" ]; then
            for ver in 85 84 83 82 81; do
                if [ -f "/usr/bin/php${ver}" ]; then
                    # Create symlink so 'php' command is available (needed for phpkg script shebang)
                    # Check if we need sudo for symlink creation
                    if [ "$(id -u)" != "0" ] && command -v sudo &> /dev/null; then
                        sudo ln -sf "/usr/bin/php${ver}" /usr/bin/php
                    else
                        ln -sf "/usr/bin/php${ver}" /usr/bin/php
                    fi
                    PHP_CMD="php"
                    break
                fi
            done
        fi
    fi
fi

# Final check - if PHP_CMD is still "php", verify it exists
if [ "$PHP_CMD" = "php" ] && ! command -v php &> /dev/null; then
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
                # On Arch Linux, PHP extensions (mbstring, curl, zip) are built into the main php package
                sudo pacman -S --noconfirm php
                ;;
            alpine)
                echo "Detected Alpine Linux"
                # Determine if we need sudo (check if we're root or if sudo is available)
                APK_CMD="apk"
                if [ "$(id -u)" != "0" ]; then
                    if command -v sudo &> /dev/null; then
                        APK_CMD="sudo apk"
                    else
                        echo "Error: This script needs root privileges or sudo to install packages on Alpine Linux."
                        echo "Please run as root or install sudo first."
                        exit 1
                    fi
                fi
                
                $APK_CMD update
                # Alpine uses versioned package names like php83-mbstring for PHP 8.3
                # Note: PHP is not installed yet at this point, so we'll try common versions
                PHP_VER=""
                
                # Try to install PHP and extensions with detected or common versions
                INSTALLED=false
                INSTALLED_VER=""
                if [ -n "$PHP_VER" ] && [ "$PHP_VER" != "8" ]; then
                    # Try detected version first
                    if $APK_CMD add --no-cache "php${PHP_VER}" "php${PHP_VER}-mbstring" "php${PHP_VER}-curl" "php${PHP_VER}-zip"; then
                        INSTALLED=true
                        INSTALLED_VER="$PHP_VER"
                    fi
                fi
                
                # Fallback: try common versions if not installed yet (newest first)
                if [ "$INSTALLED" = false ]; then
                    for ver in 85 84 83 82 81; do
                        if $APK_CMD add --no-cache "php${ver}" "php${ver}-mbstring" "php${ver}-curl" "php${ver}-zip"; then
                            INSTALLED=true
                            INSTALLED_VER="$ver"
                            break
                        fi
                    done
                fi
                
                if [ "$INSTALLED" = false ]; then
                    echo "Error: Could not install PHP with extensions. Installation failed."
                    exit 1
                else
                    # On Alpine, php83 installs /usr/bin/php83, not /usr/bin/php
                    # Create a symlink so 'php' command is available (needed for phpkg script shebang)
                    if [ -n "$INSTALLED_VER" ] && [ -f "/usr/bin/php${INSTALLED_VER}" ]; then
                        # Create symlink so phpkg script can execute (it uses #!/usr/bin/env php)
                        # Use sudo if needed (APK_CMD already determined above)
                        if [ "$(id -u)" != "0" ] && command -v sudo &> /dev/null; then
                            sudo ln -sf "/usr/bin/php${INSTALLED_VER}" /usr/bin/php
                        else
                            ln -sf "/usr/bin/php${INSTALLED_VER}" /usr/bin/php
                        fi
                        PHP_CMD="php"
                    fi
                fi
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
    # Use case-insensitive matching for extension names
    if ! $PHP_CMD -m 2>/dev/null | grep -qiE "^\s*${ext}\s*$"; then
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
                    # On Arch Linux, extensions are built into php package
                    # They just need to be enabled in php.ini, which is usually done by default
                    echo "On Arch Linux, ${ext} should be available in the php package. If not, check php.ini configuration."
                    ;;
                alpine)
                    # Alpine uses versioned package names
                    # Determine if we need sudo (check if we're root or if sudo is available)
                    APK_CMD="apk"
                    if [ "$(id -u)" != "0" ]; then
                        if command -v sudo &> /dev/null; then
                            APK_CMD="sudo apk"
                        else
                            echo "Error: This script needs root privileges or sudo to install packages on Alpine Linux."
                            exit 1
                        fi
                    fi
                    
                    # Get PHP version from installed PHP (should be available after main installation)
                    # Use $PHP_CMD which was set during the main PHP installation
                    PHP_VER=""
                    if [ -n "$PHP_CMD" ]; then
                        PHP_VER=$($PHP_CMD -r 'echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;' 2>/dev/null || echo "")
                    fi
                    
                    INSTALLED=false
                    if [ -n "$PHP_VER" ] && [ "$PHP_VER" != "8" ]; then
                        $APK_CMD add --no-cache "php${PHP_VER}-${ext}" && INSTALLED=true
                    fi
                    
                    # Fallback: try common versions if not installed yet (newest first)
                    if [ "$INSTALLED" = false ]; then
                        for ver in 85 84 83 82 81; do
                            if $APK_CMD add --no-cache "php${ver}-${ext}"; then
                                INSTALLED=true
                                break
                            fi
                        done
                    fi
                    ;;
            esac
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # On macOS, extensions should be included, but if not, reinstall PHP
            echo "${ext} should be included with Homebrew PHP. If this persists, try: brew reinstall php"
        fi
    fi
done

# Verify all extensions are now loaded
# Use case-insensitive matching and look for extensions in the PHP Modules section
for ext in $php_extensions; do
    # Get PHP modules output and check if extension is listed (case-insensitive, whole word)
    if ! $PHP_CMD -m 2>/dev/null | grep -qiE "^\s*${ext}\s*$"; then
        echo -e "${RED}Error: ${ext} extension is required but could not be installed. Please install it manually.${DEFAULT_COLOR}"
        exit 1
    fi
done

PHP_VERSION=$($PHP_CMD -r 'echo PHP_VERSION;' 2>/dev/null)

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
if ! curl -s -L -f "https://github.com/php-repos/phpkg/releases/download/$phpkg_version/phpkg.zip" -o "$temp_path/phpkg.zip"; then
    echo -e "${RED}Error: Failed to download phpkg. Please check your internet connection and try again.${DEFAULT_COLOR}"
    exit 1
fi

# Verify the downloaded file exists and has content
if [ ! -f "$temp_path/phpkg.zip" ] || [ ! -s "$temp_path/phpkg.zip" ]; then
    echo -e "${RED}Error: Downloaded file is empty or missing.${DEFAULT_COLOR}"
    exit 1
fi

echo -e "${GREEN}Download finished${DEFAULT_COLOR}"

echo "Setting up..."

# Preserve credentials.json if it exists (user may have configured it)
existing_credentials_path=""
if [ "$is_update" = true ] && [ -f "$root_path/credentials.json" ]; then
    echo "Preserving existing credentials.json..."
    # Use a temporary file to avoid command injection risks
    existing_credentials_path=$(mktemp)
    cp "$root_path/credentials.json" "$existing_credentials_path"
fi

rm -fR "$root_path"
unzip -q -o "$temp_path"/phpkg.zip -d "$temp_path"
mv "$temp_path"/production "$root_path"

# Restore existing credentials if we had them, otherwise create from example
if [ -n "$existing_credentials_path" ] && [ -f "$existing_credentials_path" ]; then
    echo "Restoring existing credentials.json..."
    cp "$existing_credentials_path" "$root_path/credentials.json"
    rm -f "$existing_credentials_path"
else
    echo "Creating credentials.json from example..."
    cp "$root_path"/credentials.example.json "$root_path"/credentials.json
fi

DEFAULT_SHELL=$(echo "$SHELL")

EXPORT_PATH="export PATH=\"\$PATH:$root_path\""

eval $EXPORT_PATH

# Add to initialization file based on shell (only if not already present)
# Use a more specific pattern to match the actual export statement
check_path_in_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # Check for the exact export statement (most specific first)
        # This avoids false positives from comments or other contexts
        if grep -qF "PATH=\"\$PATH:$root_path\"" "$file" 2>/dev/null || \
           grep -qF "PATH=\$PATH:$root_path" "$file" 2>/dev/null; then
            return 0
        fi
        # Fallback: check if path appears as a PATH entry (with leading colon or at start/end)
        # Escape special characters in path for regex matching
        local escaped_path=$(echo "$root_path" | sed 's/[[\.*^$()+?{|]/\\&/g')
        if grep -qE "(^|:)$escaped_path(:|$)" "$file" 2>/dev/null; then
            return 0
        fi
        return 1
    else
        return 1
    fi
}

if echo "$DEFAULT_SHELL" | grep -q "zsh"; then
    if ! check_path_in_file "$HOME/.zshrc"; then
        echo "Add phpkg to zsh"
        echo "$EXPORT_PATH" >> "$HOME/.zshrc"
    else
        echo "phpkg is already in your zsh configuration"
    fi
elif echo "$DEFAULT_SHELL" | grep -q "bash"; then
    if ! check_path_in_file "$HOME/.bashrc"; then
        echo "Add phpkg to bash"
        echo "$EXPORT_PATH" >> "$HOME/.bashrc"
    else
        echo "phpkg is already in your bash configuration"
    fi
elif echo "$DEFAULT_SHELL" | grep -q "sh"; then
    if ! check_path_in_file "$HOME/.profile"; then
        echo "Add phpkg to sh"
        echo "$EXPORT_PATH" >> "$HOME/.profile"  # Use .profile for sh in Alpine
    else
        echo "phpkg is already in your profile"
    fi
else
    echo "Unsupported shell detected: $DEFAULT_SHELL"
    if ! check_path_in_file "$HOME/.profile"; then
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
