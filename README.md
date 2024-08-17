# phpkg Installation README

Welcome to the phpkg installation guide! This repository provides a convenient script for installing [phpkg](https://phpkg.com), a package manager for PHP projects.

## Introduction

Following these instructions, you can install, update and remove phpkg.

## Prerequisites

There are no prerequisites if you have Arch, Fedora, Mac, Ubuntu or are using Docker with Alpine Linux as the installation will install requirements.

For others, before you begin, ensure that the following prerequisites are met:

1. **PHP 8.0 or higher**: PHP must be installed on your system. To check your PHP version, run `php --version`. You should see "PHP 8" or a higher version.
2. **Unzip**: The `unzip` utility should be installed on your operating system. You can check if `unzip` is installed 
by running `unzip --version`. If it's not installed, you can typically install it using your system's package manager
(e.g., `apt`, `yum`, `pacman`, or `brew`).

## Install

To install `phpkg`, you can run the following command in your terminal:

```shell
bash -c "$(curl -fsSL https://raw.github.com/php-repos/phpkg-installation/master/install.sh)"
```

### What Happens During Installation

Here's what happens when you run the installation command:

1. The command downloads the installation script from the `php-repos/phpkg-installation` repository.
2. If it is possible, the script checks for prerequisites and installs the ones that do not exist.
3. The installation script performs the following actions:
   - Downloads the latest release of `phpkg`
   - Extracts the downloaded zip file and puts it under your home directory and renames it to `.phpkg`
   - Creates a `credentials.json` file in the `phpkg` root (`~/.phpkg`) directory, which you may need to configure with your credentials later.
   - Updates your shell configuration (.bashrc or .zshrc) to include the `phpkg` command in your PATH.
       
After the installation is complete, you might need to open a new terminal to use `phpkg`. 

### Verify

To verify the installation, run the following command and you should see the installed version:

```shell
phpkg --version
```

## Update

To update `phpkg`, you can follow these steps:

1. **Delete the Existing Installation**:
   First, remove the current phpkg installation. You can do this by running the following command in your terminal:
   ```shell
   rm -fR ~/.phpkg
   ``` 
   This command will remove the phpkg directory and its contents from your system.
2. **Rerun the Installation Script:**
   After removing the existing installation, you can rerun the installation script to get the latest version of phpkg
and its packages.
3. **Verify the Update:**
   To ensure that the update was successful, you can run the following command to check the installed phpkg version:
    ```shell
    phpkg --version
    ```
   You should see the latest phpkg version displayed in your terminal.

## Uninstall

To uninstall `phpkg`, you can run the following command:
```shell
rm -fR ~/.phpkg
```
This command will remove the phpkg directory from your system.

Thank you for using `phpkg`! We hope it enhances your PHP development experience.
