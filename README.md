# phpkg Installation README

Welcome to the phpkg installation guide! This repository provides a convenient script for installing [phpkg](https://phpkg.com), a package manager for PHP projects.

## Introduction

Following these instructions, you can install, update and remove phpkg.

## Prerequisites

There are no prerequisites if you have Arch, Fedora, Mac, Ubuntu, or are using Docker with Alpine Linux as the installation will install requirements automatically.

**For Windows users:** PHP and required extensions must be installed manually before running the installation script.

Before you begin, ensure that the following prerequisites are met:

1. **PHP 8.1 or higher**: PHP must be installed on your system. To check your PHP version, run `php --version`. You should see "PHP 8.1" or a higher version.
2. **Required PHP extensions**: The following PHP extensions must be enabled:
   - `mbstring` (required)
   - `curl` (required)
   - `zip` (required)
   
   You can check if extensions are loaded by running `php -m`. On Linux/macOS, the installation script will attempt to install these extensions automatically. On Windows, you must enable them manually in `php.ini`.
3. **Unzip**: The `unzip` utility should be installed on your operating system. You can check if `unzip` is installed 
by running `unzip --version`. If it's not installed, you can typically install it using your system's package manager
(e.g., `apt`, `yum`, `pacman`, or `brew`). On Windows, PowerShell's `Expand-Archive` is used, so no additional tool is needed.

## Install

### Linux and macOS

To install `phpkg` on Linux or macOS, you can run the following command in your terminal:

```shell
bash -c "$(curl -fsSL https://raw.github.com/php-repos/phpkg-installation/master/install.sh)"
```

### Windows

**Important:** Before installing phpkg on Windows, you must install PHP and enable required extensions manually.

#### Step 1: Install PHP

1. Download PHP from [windows.php.net](https://windows.php.net/download/)
2. Extract the ZIP file to a directory (e.g., `C:\php`)
3. Add the PHP directory to your PATH environment variable:
   - Open System Properties > Environment Variables
   - Edit the User or System PATH variable
   - Add the PHP directory (e.g., `C:\php`)
4. Verify installation: Open a new PowerShell window and run `php --version`

#### Step 2: Configure PHP Extensions

1. Find your `php.ini` file by running: `php --ini`
2. Copy `php.ini-development` to `php.ini` in the PHP directory (if `php.ini` doesn't exist)
3. Open `php.ini` in a text editor and:
   - Set `extension_dir = "ext"` (or the full path to your ext directory)
   - Uncomment or add the following lines:
     ```
     extension=php_mbstring.dll
     extension=php_curl.dll
     extension=php_zip.dll
     ```
4. Save the file and restart your terminal
5. Verify extensions are loaded: `php -m | findstr -i "mbstring curl zip"`

#### Step 3: Install phpkg

Once PHP and extensions are configured, open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.github.com/php-repos/phpkg-installation/master/install.ps1' -OutFile install.ps1; .\install.ps1"
```

Or if you prefer to download and run it manually:

```powershell
# Download the script
Invoke-WebRequest -Uri 'https://raw.github.com/php-repos/phpkg-installation/master/install.ps1' -OutFile install.ps1

# Run the script (bypasses execution policy for this session)
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Troubleshooting Windows Execution Policy:**

If you encounter an error like "cannot be loaded because running scripts is disabled on this system", you have two options:

1. **Bypass for this script only (recommended):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

2. **Change execution policy for current user (permanent):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   Then run: `.\install.ps1`

**Note for Windows users:**
- The installation script will check if PHP and required extensions are available
- If PHP or extensions are missing, the script will display instructions and exit
- You must install and configure PHP manually before running the installation script

### What Happens During Installation

Here's what happens when you run the installation command:

1. The command downloads the installation script from the `php-repos/phpkg-installation` repository.
2. **On Linux/macOS:** The script checks for prerequisites and installs PHP and required extensions if they don't exist.
3. **On Windows:** The script checks if PHP and required extensions are available. If not, it displays instructions and exits.
4. The installation script performs the following actions:
   - Detects if this is a fresh installation or an update
   - Downloads the latest release of `phpkg`
   - If updating, preserves your existing `credentials.json` file (so you don't lose your configuration)
   - Extracts the downloaded zip file and puts it under your home directory and renames it to `.phpkg` (Linux/macOS) or `.phpkg` in your user profile (Windows)
   - Creates a `credentials.json` file from the example if it doesn't exist (on fresh installations)
   - On Windows, creates a `phpkg.bat` wrapper file to make the command work properly
   - Updates your shell configuration (.bashrc or .zshrc on Unix-like systems) or Windows PATH environment variable to include the `phpkg` command in your PATH.
       
After the installation is complete, you might need to open a new terminal to use `phpkg`.

**Note:** You can safely re-run the installation script at any time to update phpkg to the latest version. Your credentials will be preserved during updates. 

### Verify

To verify the installation, run the following command and you should see the installed version:

```shell
phpkg --version
```

## Update

To update `phpkg` to the latest version, simply **rerun the installation script**. The script will automatically:

- Detect the existing installation
- Preserve your `credentials.json` file (so you don't lose your configuration)
- Remove the old installation
- Install the latest version
- Update your PATH if needed

**Linux/macOS:**
```shell
bash -c "$(curl -fsSL https://raw.github.com/php-repos/phpkg-installation/master/install.sh)"
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.github.com/php-repos/phpkg-installation/master/install.ps1' -OutFile install.ps1; .\install.ps1"
```

**Verify the Update:**
After the update completes, open a new terminal and run:
```shell
phpkg --version
```
You should see the latest phpkg version displayed in your terminal.

**Note:** You can also manually remove the installation first if you prefer, but it's not necessary as the script handles it automatically.

## Uninstall

To uninstall `phpkg`, you can run the following command:

**Linux/macOS:**
```shell
rm -fR ~/.phpkg
```

**Windows (PowerShell):**
```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\.phpkg
```

This command will remove the phpkg directory from your system.

**Note for Windows users:** You may also want to remove phpkg from your PATH environment variable manually through System Properties > Environment Variables if it was added there.

Thank you for using `phpkg`! We hope it enhances your PHP development experience.
