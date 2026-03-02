#!/usr/bin/env pwsh
# Visual Studio 2012–2026 Offline Downloader (ISO + Layout, Download-Only)

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

    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = "GET"
    $response = $request.GetResponse()
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
}

function Select-Language {
    $languages = @(
        "en-US","de-DE","fr-FR","es-ES","ja-JP","zh-CN","ru-RU"
    )
    Write-Host "`nAvailable languages:"
    $languages | ForEach-Object { Write-Host "- $_" }
    $lang = Read-Host "Enter language code (default en-US)"
    if ([string]::IsNullOrWhiteSpace($lang)) { $lang = "en-US" }
    return $lang
}

# --- Version / Edition Maps ---------------------------------------------

$versions = @{
    "1" = @{ Name = "Visual Studio 2012";  Type = "ISO";       Id = "2012" }
    "2" = @{ Name = "Visual Studio 2013";  Type = "ISO";       Id = "2013" }
    "3" = @{ Name = "Visual Studio 2015";  Type = "ISO";       Id = "2015" }
    "4" = @{ Name = "Visual Studio 2017";  Type = "Bootstrap"; Id = "2017" }
    "5" = @{ Name = "Visual Studio 2019";  Type = "Bootstrap"; Id = "2019" }
    "6" = @{ Name = "Visual Studio 2022";  Type = "Bootstrap"; Id = "2022" }
    "7" = @{ Name = "Visual Studio 2026";  Type = "Bootstrap"; Id = "2026" }
}

$bootstrapMap = @{
    "2017" = @{ Major = "15"; Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/15/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/15/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/15/release/vs_community.exe" }
    }}
    "2019" = @{ Major = "16"; Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/16/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/16/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/16/release/vs_community.exe" }
    }}
    "2022" = @{ Major = "17"; Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/17/release/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/17/release/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/17/release/vs_community.exe" }
    }}
    "2026" = @{ Major = "18"; Editions = @{
        "1" = @{ Name="Enterprise";   Url="https://aka.ms/vs/18/stable/vs_enterprise.exe" }
        "2" = @{ Name="Professional"; Url="https://aka.ms/vs/18/stable/vs_professional.exe" }
        "3" = @{ Name="Community";    Url="https://aka.ms/vs/18/stable/vs_community.exe" }
    }}
}

# ISO URLs: ENU only (user responsible for licensing/usage)
$isoMap = @{
    "2012" = @{
        "1" = @{ Name="Professional ENU"; Url="https://download.microsoft.com/download/1/2/3/VS2012_PRO_ENU.iso" }
        "2" = @{ Name="Ultimate ENU";     Url="https://download.microsoft.com/download/4/5/6/VS2012_ULT_ENU.iso" }
    }
    "2013" = @{
        "1" = @{ Name="Professional ENU"; Url="https://download.microsoft.com/download/7/8/9/VS2013_PRO_ENU.iso" }
        "2" = @{ Name="Ultimate ENU";     Url="https://download.microsoft.com/download/A/B/C/VS2013_ULT_ENU.iso" }
    }
    "2015" = @{
        "1" = @{ Name="Enterprise ENU";   Url="https://download.microsoft.com/download/D/E/F/VS2015_ENT_ENU.iso" }
        "2" = @{ Name="Professional ENU"; Url="https://download.microsoft.com/download/G/H/I/VS2015_PRO_ENU.iso" }
        "3" = @{ Name="Community ENU";    Url="https://download.microsoft.com/download/J/K/L/VS2015_COMM_ENU.iso" }
    }
}

# NOTE: Above ISO URLs are placeholders – replace with actual official links you trust.

# --- Main Menu ----------------------------------------------------------

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

# --- ISO-based versions (2012/2013/2015) --------------------------------

if ($version.Type -eq "ISO") {
    $vid = $version.Id
    if (-not $isoMap.ContainsKey($vid)) {
        Write-Host "No ISO map defined for $($version.Name). You must provide your own ISO."
        exit
    }

    Write-Host "`nSelect edition (ISO download, ENU only; licensing and installation are your responsibility):"
    $isoMap[$vid].GetEnumerator() | Sort-Object Key | ForEach-Object {
        Write-Host "$($_.Key) = $($_.Value.Name)"
    }
    $isoSel = Read-Host "Enter number"
    if (-not $isoMap[$vid].ContainsKey($isoSel)) {
        Write-Host "Invalid selection."
        exit
    }

    $isoInfo = $isoMap[$vid][$isoSel]
    $targetDir = Join-Path $RootPath $version.Id
    Ensure-Dir -Path $targetDir

    $fileName = Split-Path $isoInfo.Url -Leaf
    $outFile = Join-Path $targetDir $fileName

    Write-Host "`nDownloading ISO for $($version.Name) - $($isoInfo.Name)"
    Write-Host "URL: $($isoInfo.Url)"
    Write-Host "Target: $outFile"
    Download-FileWithProgress -Uri $isoInfo.Url -OutFile $outFile -Label "Downloading ISO"

    Write-Host "`nDownload complete."
    Write-Host "ISO stored at: $outFile"
    Write-Host "Installation and licensing are your responsibility."
    exit
}

# --- Bootstrapper-based versions (2017+) --------------------------------

$vid = $version.Id
if (-not $bootstrapMap.ContainsKey($vid)) {
    Write-Host "No bootstrapper map defined for $($version.Name)."
    exit
}

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
Download-FileWithProgress -Uri $edition.Url -OutFile $bootstrapperPath -Label "Downloading bootstrapper"

$layoutPath = Join-Path $versionDir "Layout_$($edition.Name)_$lang"
Ensure-Dir -Path $layoutPath

Write-Host "`nCreating/Updating offline layout at: $layoutPath"
$argList = @("--layout", $layoutPath, "--lang", $lang)

$proc = Start-Process -FilePath $bootstrapperPath -ArgumentList $argList -PassThru -Wait

Write-Host "`nLayout process finished."

# VS 2017–2022: vs_setup.exe; VS 2026: setup.exe (but we check both)
$setupCandidates = @(
    Join-Path $layoutPath "vs_setup.exe",
    Join-Path $layoutPath "setup.exe"
)

$installerPath = $setupCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $installerPath) {
    Write-Host "WARNING: No setup executable found in layout folder."
    Write-Host "Check the layout manually at: $layoutPath"
    exit
}

Write-Host "`nOffline layout ready."
Write-Host "Layout path: $layoutPath"
Write-Host "Installer:   $installerPath"
Write-Host "`nYou can now copy this folder to an offline machine and run the installer there."
