#!/usr/bin/env pwsh

param(
    [string]$LayoutPath = "$PSScriptRoot/VSLayout"
)

# Elevate if needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Start-Process pwsh "-File `"$PSCommandPath`" -LayoutPath `"$LayoutPath`"" -Verb RunAs
    exit
}

# Edition selector
$edition = Read-Host @"
Select Visual Studio Edition:
1 = Enterprise
2 = Professional
3 = Community
Enter number:
"@



$Bootstrapper = Join-Path $PSScriptRoot "vs_bootstrapper.exe"

Write-Host "Downloading official Visual Studio bootstrapper..."
Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $Bootstrapper

# Ensure layout folder exists
if (-not (Test-Path $LayoutPath)) {
    New-Item -ItemType Directory -Path $LayoutPath | Out-Null
}

Write-Host "`nCreating/Updating offline layout..."
& $Bootstrapper --layout $LayoutPath

Write-Host "`nOffline layout ready at: $LayoutPath"

$installerPath = Join-Path $LayoutPath "vs_setup.exe"

if (-not (Test-Path $installerPath)) {
    Write-Host "ERROR: vs_setup.exe not found in layout folder."
    exit
}

$install = Read-Host "`nInstall now? (Y/N)"
if ($install -match "^[Yy]$") {
    & $installerPath --noweb --wait
}

Write-Host "`nDone."
