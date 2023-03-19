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
packages_path=$root_path/Packages/php-repos
cli_path=$packages_path/cli
datatype_path=$packages_path/datatype
file_manager_path=$packages_path/file-manager
control_flow_path=$packages_path/control-flow

phpkg_version="v1.2.1"
cli_version="v1.0.1"
datatype_version="v1.0.1"
file_manager_version="v2.0.0"
control_flow_version="v1.0.0"

if ! command -v php &> /dev/null
then
    echo "PHP if not installed"
    exit
fi
PHP_VERSION=$(php --version | grep "PHP "\[1-9] -o)

if [ "${PHP_VERSION}" == "PHP 8" ]
then
  PHP_VERSION=$(php --version | grep "PHP "\[1-9])
  echo "${PHP_VERSION} detected"
else
  echo -e "${RED}Required PHP version not detected! phpkg needs PHP >= 8.0 ${DEFAULT_COLOR}"
  exit
fi

echo -e "Installing phpkg version: ${GREEN}${phpkg_version}${DEFAULT_COLOR} ..."
echo -e "Downloading phpkg"
curl -s -L https://github.com/php-repos/phpkg/zipball/$phpkg_version > "$temp_path"/phpkg.zip

echo -e "Downloading CLI version ${GREEN}${cli_version}${DEFAULT_COLOR}"
curl -s -L https://github.com/php-repos/cli/zipball/$cli_version > "$temp_path"/cli.zip

echo -e "Downloading Datatype version ${GREEN}${datatype_version}${DEFAULT_COLOR}"
curl -s -L https://github.com/php-repos/datatype/zipball/$datatype_version > "$temp_path"/datatype.zip

echo -e "Downloading FileManager version ${GREEN}${file_manager_version}${DEFAULT_COLOR}"
curl -s -L https://github.com/php-repos/file-manager/zipball/$file_manager_version > "$temp_path"/file-manager.zip

echo -e "Downloading ControlFlow version ${GREEN}${control_flow_version}${DEFAULT_COLOR}"
curl -s -L https://github.com/php-repos/control-flow/zipball/$control_flow_version > "$temp_path"/control-flow.zip

echo -e "${GREEN}Download finished${DEFAULT_COLOR}"

echo "Setting up..."
rm -fR "$root_path"
unzip -q -o "$temp_path"/phpkg.zip -d "$temp_path"
mv "$temp_path/$(ls "$temp_path" | grep php-repos-phpkg)" "$root_path"

echo "Make Packages directory"
rm -fR "$packages_path"
mkdir -p "$packages_path"

echo "Setting up CLI ..."
unzip -q -o "$temp_path"/cli.zip -d "$temp_path"
mv "$temp_path/$(ls "$temp_path" | grep php-repos-cli)" "$cli_path"

echo "Setting up Datatype ..."
unzip -q -o "$temp_path"/datatype.zip -d "$temp_path"
mv "$temp_path/$(ls "$temp_path" | grep php-repos-datatype)" "$datatype_path"

echo "Setting up FileManager ..."
unzip -q -o "$temp_path"/file-manager.zip -d "$temp_path"
mv "$temp_path/$(ls "$temp_path" | grep php-repos-file-manager)" "$file_manager_path"

echo "Setting up ControlFlow ..."
unzip -q -o "$temp_path"/control-flow.zip -d "$temp_path"
mv "$temp_path/$(ls "$temp_path" | grep php-repos-control-flow)" "$control_flow_path"

echo "Make credential file"
cp "$root_path"/credentials.example.json "$root_path"/credentials.json

DEFAULT_SHELL=$(echo "$SHELL")

EXPORT_PATH='export PATH="$PATH:'$root_path'"'

if [[ "$DEFAULT_SHELL" =~ .*"zsh".* ]]
then
  echo "Add phpkg to zsh"
  echo $EXPORT_PATH >> $HOME/.zshrc
else
  echo "Add phpkg to bash"
  echo $EXPORT_PATH >> $HOME/.bashrc
fi

echo -e "${YELLOW}- Please open a new terminal to start working with phpkg.${DEFAULT_COLOR}"
if [ -z "${GITHUB_TOKEN}" ];
then
  echo -e "${YELLOW}- Please add your credential using the credential command. Visit https://phpkg.com/documentations/credential-command ${DEFAULT_COLOR}"
else
  echo -e "${GREEN}- GITHUB_TOKEN found in environment variables. No need to add token for GitHub."
fi

echo -e "\n${GREEN}Installation finished successfully. Enjoy.${DEFAULT_COLOR}"
