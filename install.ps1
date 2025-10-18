# Requires Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

# --- Terms of Use ---
Clear-Host
Write-Host "`n ================================" -ForegroundColor Cyan
Write-Host "     CODEX Installer" -ForegroundColor Cyan
Write-Host " ================================" -ForegroundColor Cyan
Write-Host "`n TERMS OF USE" -ForegroundColor Yellow
Write-Host " --------------------------------" -ForegroundColor Yellow
Write-Host " 1. This software is provided 'as is', without warranty of any kind." -ForegroundColor White
Write-Host " 2. The user assumes all risk for the use of this software." -ForegroundColor White
Write-Host " 3. You may not reverse engineer, decompile, or disassemble this software." -ForegroundColor White
Write-Host " 4. This software is for personal, non-commercial use only." -ForegroundColor White
Write-Host "`n By continuing with this installation, you agree to these terms." -ForegroundColor Yellow
Write-Host " --------------------------------" -ForegroundColor Yellow

$agree = Read-Host "`nDo you accept the terms and wish to continue? (Y/N)"
if ($agree -ne "y" -and $agree -ne "Y") {
    Write-Host "Installation cancelled by user." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit
}

# --- .NET SDK Check and Install ---
Write-Host "`nChecking for .NET SDK 8.0 (x64)..." -ForegroundColor Green
try {
    $dotnetPath = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
} catch {
    $dotnetPath = $null
}

if (-not $dotnetPath) {
    Write-Host ".NET SDK 8.0 (x64) not found. Downloading and installing..." -ForegroundColor Yellow
    $dotnetSdkInstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/11111111-1111-1111-1111-111111111111/22222222222222222222222222222222/dotnet-sdk-8.0.100-win-x64.exe"
    $dotnetSdkInstallerName = "dotnet-sdk-8.0.100-win-x64.exe"
    $tempInstallerPath = Join-Path $env:TEMP $dotnetSdkInstallerName

    Write-Host "Downloading .NET SDK from $dotnetSdkInstallerUrl..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $dotnetSdkInstallerUrl -FollowRelocation -OutFile $tempInstallerPath -ErrorAction Stop
    } catch {
        Write-Host "Failed to download .NET SDK: $_" -ForegroundColor Red
        Write-Host "Please download and install it manually from https://dotnet.microsoft.com/en-us/download/dotnet/8.0" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Exit
    }

    Write-Host "Installing .NET SDK 8.0..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $tempInstallerPath -ArgumentList "/install /quiet /norestart" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host ".NET SDK installation failed. Exit Code: $($process.ExitCode)" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Exit
    }
    Write-Host ".NET SDK installed successfully." -ForegroundColor Green
} else {
    Write-Host ".NET SDK 8.0 found at $dotnetPath." -ForegroundColor Green
}

# --- Application Source Download and Build ---
Write-Host "`nDownloading CODEX source code..." -ForegroundColor Green
$appSourceDownloadUrl = "https://github.com/Melon4Program/CODEX/raw/main/CODEX.zip"
$appSourceZipName = "CODEX_Source.zip"
$tempSourcePath = Join-Path $env:TEMP "CODEX_Source_Extract"
$tempZipPath = Join-Path $env:TEMP $appSourceZipName

Write-Host "Downloading source code from $appSourceDownloadUrl..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $appSourceDownloadUrl -OutFile $tempZipPath -ErrorAction Stop
} catch {
    Write-Host "Failed to download CODEX source code: $_" -ForegroundColor Red
    Write-Host "Please check your internet connection or the provided URL." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
Write-Host "Source code downloaded. Extracting..." -ForegroundColor Green

# Ensure tempSourcePath is clean
if (Test-Path $tempSourcePath) { Remove-Item -Path $tempSourcePath -Recurse -Force }
New-Item -Path $tempSourcePath -ItemType Directory | Out-Null

try {
    Expand-Archive -Path $tempZipPath -DestinationPath $tempSourcePath -Force -ErrorAction Stop
} catch {
    Write-Host "Failed to extract source code: $_" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
Write-Host "Source code extracted to $tempSourcePath." -ForegroundColor Green

Write-Host "`nBuilding CODEX application..." -ForegroundColor Green
$extractedRepoPath = $tempSourcePath # Corrected: files are directly in tempSourcePath
if (-not (Test-Path $extractedRepoPath)) {
    Write-Host "Extracted source directory not found: $extractedRepoPath. Zip file structure might be unexpected." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}

Set-Location $extractedRepoPath
try {
    dotnet publish CODEX.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeAllContentForSelfExtract=true
} catch {
    Write-Host "Application build failed: $_" -ForegroundColor Red
    Write-Host "Please check the build output for errors." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
Write-Host "Application built successfully." -ForegroundColor Green

# --- Copy Published Output and Create Shortcut ---
$installPath = "C:\Program Files\CODEX"
$publishedOutputPath = Join-Path $extractedRepoPath "bin\Release\net8.0-windows\win-x64\publish"

Write-Host "`nCreating installation directory: $installPath" -ForegroundColor Green
# Ensure installPath is clean before copying
if (Test-Path $installPath) { Remove-Item -Path $installPath -Recurse -Force }
New-Item -Path $installPath -ItemType Directory | Out-Null

Write-Host "Copying published application files..." -ForegroundColor Cyan
try {
    Copy-Item -Path (Join-Path $publishedOutputPath "*") -Destination $installPath -Recurse -Force -ErrorAction Stop
} catch {
    Write-Host "Failed to copy published files: $_" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
Write-Host "Published application files copied." -ForegroundColor Green

Write-Host "`nCreating Desktop shortcut..." -ForegroundColor Green
$shortcutPath = Join-Path $env:USERPROFILE "Desktop\CODEX.lnk"
$targetPath = Join-Path $installPath "CODEX.exe"

try {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($shortcutPath)
    $s.TargetPath = $targetPath
    $s.WorkingDirectory = $installPath # Explicitly set working directory
    $s.IconLocation = "$targetPath,0"
    $s.Save()
} catch {
    Write-Host "Failed to create desktop shortcut: $_" -ForegroundColor Red
    Write-Host "This might be due to security software or permissions. Please try creating the shortcut manually to $targetPath." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
Write-Host "Desktop shortcut created." -ForegroundColor Green

# --- Cleaning up temporary files ---
Write-Host "`nCleaning up temporary files..." -ForegroundColor Green
if (Test-Path $tempSourcePath) { Remove-Item -Path $tempSourcePath -Recurse -Force }
if (Test-Path $tempZipPath) { Remove-Item -Path $tempZipPath -Force }
if (Test-Path $tempInstallerPath) { Remove-Item -Path $tempInstallerPath -Force }
Write-Host "Temporary files cleaned up." -ForegroundColor Green

Write-Host "`n ================================" -ForegroundColor Green
Write-Host "     Installation Complete!" -ForegroundColor Green
Write-Host " ================================" -ForegroundColor Green
Write-Host "`nYou can now run CODEX from the shortcut on your Desktop." -ForegroundColor Green
Read-Host "Press Enter to exit."
