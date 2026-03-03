#!/usr/bin/env pwsh
# Visual Studio 2017–2026 Offline Layout Downloader (Download-only, modern systems)

param(
    [string]$RootPath = "$PSScriptRoot/VS_Offline"
)

# --- Helpers -------------------------------------------------------------

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Download-FileWithProgress {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$Label = "Downloading"
    )

    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Method = "GET"
        $response = $request.GetResponse()
    } catch {
        Write-Host "Download failed: $($_.Exception.Message)"
        return $false
    }

    $totalBytes = $response.ContentLength
    $stream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create)

    $buffer = New-Object byte[] 65536
    $totalRead = 0
    $lastPercent = -1

    try {
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            if ($totalBytes -gt 0) {
                $percent = [int](($totalRead / $totalBytes) * 100)
                if ($percent -ne $lastPercent) {
                    Write-Progress -Activity $Label -Status "$percent% ($([math]::Round($totalRead/1MB,2)) MB / $([math]::Round($totalBytes/1MB,2)) MB)" -PercentComplete $percent
                    $lastPercent = $percent
                }
            } else {
                Write-Progress -Activity $Label -Status "$([math]::Round($totalRead/1MB,2)) MB downloaded" -PercentComplete 0
            }
        }
    }
    finally {
        $fileStream.Close()
        $stream.Close()
        $response.Close()
        Write-Progress -Activity $Label -Completed
    }

    return $true
}

function Select-Language {
    $languages = @(
        "en-US","de-DE","fr-FR","es-ES","ja-JP","zh-CN","ru-RU"
    )

    Write-Host "`nSelect Language:"
    for ($i=0; $i -lt $languages.Count; $i++) {
        Write-Host "$($i+1) = $($languages[$i])"
    }

    $sel = Read-Host "Enter number (default 1)"
    if ([string]::IsNullOrWhiteSpace($sel)) { return $languages[0] }

    $index = [int]$sel - 1
    if ($index -lt 0 -or $index -ge $languages.Count) {
        Write-Host "Invalid selection. Using en-US."
        return "en-US"
    }

    return $languages[$index]
}

# --- Version / Edition Maps (2017–2026) ---------------------------------

$versions = @{
    "1" = @{ Name = "Visual Studio 2017"; Id = "2017" }
    "2" = @{ Name = "Visual Studio 2019"; Id = "2019" }
    "3" = @{ Name = "Visual Studio 2022"; Id = "2022" }
    "4" = @{ Name = "Visual Studio 2026"; Id = "2026" }
}

$bootstrapMap = @{
    "2017" = @{ Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/15/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/15/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/15/release/vs_community.exe" }
    }}
    "2019" = @{ Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/16/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/16/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/16/release/vs_community.exe" }
    }}
    "2022" = @{ Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/17/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/17/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/17/release/vs_community.exe" }
    }}
    "2026" = @{ Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/18/stable/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/18/stable/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/18/stable/vs_community.exe" }
    }}
}

# --- Main ---------------------------------------------------------------

Ensure-Dir -Path $RootPath

Write-Host "Select Visual Studio Version:`n"
$versions.GetEnumerator() | Sort-Object Key | ForEach-Object {
    Write-Host "$($_.Key) = $($_.Value.Name)"
}
$verSel = Read-Host "Enter number"
if (-not $versions.ContainsKey($verSel)) {
    Write-Host "Invalid selection."
    exit
}

$version = $versions[$verSel]
$vid = $version.Id

$bm = $bootstrapMap[$vid]

Write-Host "`nSelect Edition:"
$bm.Editions.GetEnumerator() | Sort-Object Key | ForEach-Object {
    Write-Host "$($_.Key) = $($_.Value.Name)"
}
$edSel = Read-Host "Enter number"
if (-not $bm.Editions.ContainsKey($edSel)) {
    Write-Host "Invalid selection."
    exit
}

$edition = $bm.Editions[$edSel]
$lang = Select-Language

$versionDir = Join-Path $RootPath $version.Id
Ensure-Dir -Path $versionDir

$bootstrapperPath = Join-Path $versionDir "vs_bootstrapper_$($edition.Name).exe"

Write-Host "`nDownloading bootstrapper for $($version.Name) - $($edition.Name)"
Write-Host "URL: $($edition.Url)"
Write-Host "Target: $bootstrapperPath"

if (-not (Download-FileWithProgress -Uri $edition.Url -OutFile $bootstrapperPath -Label "Downloading bootstrapper")) {
    Write-Host "Bootstrapper download failed."
    exit
}

$layoutPath = Join-Path $versionDir "Layout_$($edition.Name)_$lang"
Ensure-Dir -Path $layoutPath

Write-Host "`nCreating/Updating offline layout at: $layoutPath"

$argList = @("--layout", $layoutPath, "--lang", $lang, "--quiet")

Start-Process -FilePath $bootstrapperPath -ArgumentList $argList -Wait

Write-Host "`nLayout process finished."

$setupCandidates = @(
    (Join-Path $layoutPath "vs_setup.exe"),
    (Join-Path $layoutPath "setup.exe")
)

$installerPath = $setupCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $installerPath) {
    Write-Host "WARNING: No setup executable found in layout folder."
    Write-Host "Check the layout manually at: $layoutPath"
    exit
}

Write-Host "`nOffline layout ready."
Write-Host "Layout path: $layoutPath"
Write-Host "Installer present: $installerPath"
Write-Host "`nYou can now copy this folder to an offline machine and run the installer there."
