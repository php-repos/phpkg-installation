# PHPKG Installation README

Welcome to the PHPKG installation guide! This repository provides a convenient script for installing
[phpkg](https://phpkg.com), a package manager for PHP, along with some essential packages. Follow the instructions below
to set up phpkg and its associated packages on your system.

## Introduction

PHPKG simplifies the management of PHP packages and dependencies, making it easier for PHP developers to work with
various libraries and tools. With this installation guide, you'll have phpkg up and running in no time.

## Prerequisites

Before you begin, ensure that the following prerequisites are met:

1. **PHP 8.0 or higher**: PHP must be installed on your system. To check your PHP version, run `php --version`. You
should see "PHP 8" or a higher version.
2. **Unzip**: The `unzip` utility should be installed on your operating system. You can check if `unzip` is installed 
by running `unzip --version`. If it's not installed, you can typically install it using your system's package manager
(e.g., `apt`, `yum`, `pacman`, or `brew`).

## Installation

To install phpkg and its associated packages, you can run the following command in your terminal:

```shell
bash -c "$(curl -fsSL https://raw.github.com/php-repos/phpkg-installation/master/install.sh)"
```

### What Happens During Installation

Here's what happens when you run the installation command:

1. The command downloads the installation script from the `php-repos/phpkg-installation` repository.
2. The installation script performs the following actions:
   - Checks if your system meets the prerequisites, including having PHP 8.0 or higher and the `unzip` utility installed.
   - Downloads and sets up phpkg, along with the following packages:
     - [**CLI**](https://phpkg.com/packages/cli/documentations/getting-started)
     - [**Datatype**](https://phpkg.com/packages/datatype/documentations/getting-started)
     - [**FileManager**](https://phpkg.com/packages/file-manager/documentations/getting-started)
     - [**ControlFlow**](https://phpkg.com/packages/control-flow/documentations/getting-started)
     - [**Console**](https://phpkg.com/packages/console/documentations/getting-started)
   - Creates a `credentials.json` file in the phpkg root directory, which you may need to configure with your
   credentials later.
   - Updates your shell configuration (.bashrc or .zshrc) to include phpkg in your PATH.
       
After the installation is complete, you can start using phpkg by opening a new terminal window or running the following 
command:
```shell
phpkg
```
You can now use phpkg to manage PHP packages. Refer to the 
[phpkg documentation](https://phpkg.com/documentations/getting-started) for more information on how to use phpkg and its
packages.

## Update

To update phpkg and its associated packages, you can follow these steps:

1. **Delete the Existing Installation**:
   First, remove the current phpkg installation and its associated packages. You can do this by running the following
command in your terminal:
   ```shell
   rm -fR ~/.phpkg
   ``` 
   This command will remove the phpkg directory and its contents from your system.
2. **Re-run the Installation Script:**
   After removing the existing installation, you can re-run the installation script to get the latest version of phpkg
and its packages. Use the following command in your terminal:
    ```shell
    bash -c "$(curl -fsSL https://raw.github.com/php-repos/phpkg-installation/master/install.sh)"
    ```
   This command will download and set up the latest version of phpkg, along with the associated packages. It will also
configure your system as outlined in the installation instructions.
3. **Verify the Update:**
   To ensure that the update was successful, you can run the following command to check the installed phpkg version:
    ```shell
    phpkg --version
    ```
   You should see the latest phpkg version displayed in your terminal.

## Uninstallation

To uninstall phpkg and its associated packages, you can run the following command:
```shell
rm -fR ~/.phpkg
```
This command will remove the phpkg directory and all its contents from your system.

Thank you for using phpkg! We hope it enhances your PHP development experience.
