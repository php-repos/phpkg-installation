#Requires -Version 5.1

# Set error action preference to stop on errors
# Critical commands are wrapped in try-catch blocks to handle expected failures gracefully
$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-ErrorMsg { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message }

# Load configuration from inline JSON with fallback values
# Fallback values (used when parsing fails)
$fallbackPhpkgVersion = "v3.0.0-rc1"
$fallbackPhpMinVersion = "8.1"
$fallbackPhpExtensions = @("mbstring", "curl", "zip")

# Inline configuration JSON
$configJson = @'
{
  "phpkg_version": "v3.0.1",
  "php_min_version": "8.2",
  "php_extensions": [
    "mbstring",
    "curl",
    "zip"
  ]
}
'@

# Parse inline config JSON, fallback to defaults if parsing fails
try {
    $config = $configJson | ConvertFrom-Json
    $phpkgVersion = $config.phpkg_version
    $phpMinVersion = $config.php_min_version
    $phpExtensions = $config.php_extensions
    
    # Use fallback if parsing failed or values are missing
    if (-not $phpkgVersion -or -not $phpMinVersion -or -not $phpExtensions) {
        $phpkgVersion = $fallbackPhpkgVersion
        $phpMinVersion = $fallbackPhpMinVersion
        $phpExtensions = $fallbackPhpExtensions
    }
} catch {
    # Parsing failed, use fallback values
    $phpkgVersion = $fallbackPhpkgVersion
    $phpMinVersion = $fallbackPhpMinVersion
    $phpExtensions = $fallbackPhpExtensions
}

$rootPath = Join-Path $env:USERPROFILE ".phpkg"
$tempPath = Join-Path $env:TEMP "phpkg-install-$(New-Guid)"

# Create temp directory
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

try {
    # Check if PHP is installed
    $phpInstalled = $false
    $phpVersion = $null
    try {
        $phpVersionOutput = php -r "echo PHP_VERSION;" 2>&1
        $phpVersion = ($phpVersionOutput | Select-Object -First 1).ToString().Trim()
        if ($LASTEXITCODE -eq 0 -and $phpVersion) {
            $phpInstalled = $true
        }
    } catch {
        $phpInstalled = $false
    }

    if (-not $phpInstalled) {
        Write-ErrorMsg "PHP is not installed or not found in PATH."
        Write-Info ""
        Write-Info "Please install PHP $phpMinVersion or higher manually:"
        Write-Info "  1. Download from https://windows.php.net/download/"
        Write-Info "  2. Extract to a directory (e.g., C:\php)"
        Write-Info "  3. Add PHP directory to your PATH environment variable"
        Write-Info "  4. Copy php.ini-development to php.ini in the PHP directory"
        Write-Info "  5. Enable required extensions in php.ini:"
        foreach ($ext in $phpExtensions) {
            Write-Info "     - extension=php_$ext.dll"
        }
        Write-Info "  6. Set extension_dir = `"ext`" in php.ini"
        Write-Info ""
        Write-Info "After installing PHP, run this installation script again."
        exit 1
    }

    # Verify PHP version
    $requiredVersion = [Version]$phpMinVersion
    $currentVersion = [Version]$phpVersion

    if ($currentVersion -ge $requiredVersion) {
        Write-Success "PHP $phpVersion detected"
    } else {
        Write-ErrorMsg "PHP version $phpVersion detected, but phpkg requires PHP >= $phpMinVersion."
        Write-Info "Please upgrade PHP and run this installation script again."
        exit 1
    }

    # Check required PHP extensions
    Write-Info "Checking required PHP extensions..."
    try {
        $phpModules = php -m 2>&1 | Out-String
    } catch {
        Write-ErrorMsg "Failed to get PHP modules list: $_"
        exit 1
    }
    
    $missingExtensions = @()
    foreach ($ext in $phpExtensions) {
        # Check if extension is loaded (case-insensitive, match whole word, handle whitespace)
        if ($phpModules -notmatch "(?m)^\s*$ext\s*$") {
            $missingExtensions += $ext
        }
    }

    if ($missingExtensions.Count -gt 0) {
        Write-ErrorMsg "Required PHP extensions are missing: $($missingExtensions -join ', ')"
        Write-Info ""
        Write-Info "Please enable the following extensions in your php.ini file:"
        foreach ($ext in $missingExtensions) {
            Write-Info "  - extension=php_$ext.dll"
        }
        Write-Info ""
        Write-Info "To find your php.ini file, run: php --ini"
        Write-Info "Make sure extension_dir is set correctly (e.g., extension_dir = `"ext`")"
        Write-Info ""
        Write-Info "After enabling the extensions, restart your terminal and run this script again."
        exit 1
    }
    
    Write-Success "Required PHP extensions are available"

    # Check if this is an update or fresh install
    $isUpdate = Test-Path $rootPath
    if ($isUpdate) {
        Write-Info "Updating phpkg to version: $phpkgVersion ..."
        Write-Info "Existing installation found at: $rootPath"
    } else {
        Write-Info "Installing phpkg version: $phpkgVersion ..."
    }
    
    Write-Info "Downloading phpkg"
    
    $zipPath = Join-Path $tempPath "phpkg.zip"
    $downloadUrl = "https://github.com/php-repos/phpkg/releases/download/$phpkgVersion/phpkg.zip"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        
        # Verify the downloaded file exists and has content
        if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -eq 0) {
            Write-ErrorMsg "Downloaded file is empty or missing."
            exit 1
        }
        
        Write-Success "Download finished"
    } catch {
        Write-ErrorMsg "Failed to download phpkg: $_"
        exit 1
    }

    Write-Info "Setting up..."
    
    # Preserve credentials.json if it exists (user may have configured it)
    $existingCredentials = $null
    if ($isUpdate) {
        $existingCredentialsPath = Join-Path $rootPath "credentials.json"
        if (Test-Path $existingCredentialsPath) {
            Write-Info "Preserving existing credentials.json..."
            $existingCredentials = Get-Content -Path $existingCredentialsPath -Raw
        }
    }
    
    # Remove existing installation if it exists
    if (Test-Path $rootPath) {
        Remove-Item -Path $rootPath -Recurse -Force
    }

    # Extract zip file
    Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force
    
    # Move build directory to root path
    $buildPath = Join-Path $tempPath "build"
    if (Test-Path $buildPath) {
        Move-Item -Path $buildPath -Destination $rootPath -Force
    } else {
        Write-ErrorMsg "Build directory not found in downloaded archive"
        exit 1
    }

    # Restore existing credentials if we had them, otherwise create from example
    Write-Info "Setting up credential file"
    $credentialsExample = Join-Path $rootPath "credentials.example.json"
    $credentials = Join-Path $rootPath "credentials.json"
    
    if ($existingCredentials) {
        Write-Info "Restoring existing credentials.json..."
        Set-Content -Path $credentials -Value $existingCredentials -NoNewline
    } elseif (Test-Path $credentialsExample) {
        Write-Info "Creating credentials.json from example..."
        Copy-Item -Path $credentialsExample -Destination $credentials -Force
    }

    # Create Windows batch wrapper for phpkg
    Write-Info "Creating Windows batch wrapper..."
    $phpkgBatPath = Join-Path $rootPath "phpkg.bat"
    # Use %~dp0 to get the batch file's directory and properly handle paths with spaces
    # Pass through exit codes to the calling process
    $batchContent = @"
@echo off
php "%~dp0phpkg" %*
exit /b %ERRORLEVEL%
"@
    Set-Content -Path $phpkgBatPath -Value $batchContent -Encoding ASCII

    # Add to PATH
    $phpkgBinPath = $rootPath
    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # Check if path is already in PATH (more precise check to avoid false positives)
    $pathEntries = $currentUserPath -split ';' | Where-Object { $_ -ne '' }
    $pathExists = $false
    foreach ($entry in $pathEntries) {
        if ($entry -eq $phpkgBinPath) {
            $pathExists = $true
            break
        }
    }
    
    if (-not $pathExists) {
        Write-Info "Adding phpkg to PATH"
        $newPath = $currentUserPath
        if ($newPath -and -not $newPath.EndsWith(";")) {
            $newPath += ";"
        }
        $newPath += $phpkgBinPath
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path += ";$phpkgBinPath"
        Write-Success "phpkg has been added to your PATH"
    } else {
        Write-Info "phpkg is already in your PATH"
    }

    if ($isUpdate) {
        Write-Success "`nUpdate finished successfully! phpkg has been updated to version $phpkgVersion."
    } else {
        Write-Success "`nInstallation finished successfully. Enjoy."
    }
    Write-Info "Note: You may need to restart your terminal for PATH changes to take effect."
    Write-Info ""
    Write-Info "To update phpkg in the future, simply run this installation script again."
    
} finally {
    # Cleanup temp directory
    if (Test-Path $tempPath) {
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
