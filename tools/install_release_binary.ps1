param(
    [string]$Repo = "TieZhuzhu/deep-read-web",
    [ValidateSet("auto", "small", "full")]
    [string]$Flavor = "auto",
    [string]$Tag
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$binDir = Join-Path $repoRoot "skills\deep-read-web\bin"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

function Test-SystemChromiumBrowser {
    $candidates = @(
        (Join-Path $env:PROGRAMFILES "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path ${env:PROGRAMFILES(X86)} "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:PROGRAMFILES "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:PROGRAMFILES(X86)} "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $true
        }
    }

    return $false
}

$resolvedFlavor = $Flavor
if ($resolvedFlavor -eq "auto") {
    $resolvedFlavor = if (Test-SystemChromiumBrowser) { "small" } else { "full" }
}

$assetName = if ($resolvedFlavor -eq "full") {
    "deep_read-windows-x64-with-chromium.zip"
}
else {
    "deep_read-windows-x64.zip"
}

$releaseApi = if ($Tag) {
    "https://api.github.com/repos/$Repo/releases/tags/$Tag"
}
else {
    "https://api.github.com/repos/$Repo/releases/latest"
}

Write-Host "Fetching release metadata from $releaseApi" -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri $releaseApi -Headers @{ "User-Agent" = "deep-read-web-installer" }
$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1

if (-not $asset) {
    throw "Release asset '$assetName' was not found in $Repo."
}

$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("deep-read-web-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
$tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("deep-read-web-" + [System.Guid]::NewGuid().ToString("N"))

try {
    Write-Host "Resolved flavor: $resolvedFlavor" -ForegroundColor Cyan
    Write-Host "Downloading $assetName ..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -Headers @{ "User-Agent" = "deep-read-web-installer" }

    New-Item -ItemType Directory -Force -Path $tempExtractDir | Out-Null
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtractDir -Force

    $downloadedExe = Join-Path $tempExtractDir "deep_read.exe"
    if (-not (Test-Path $downloadedExe)) {
        throw "Downloaded archive does not contain deep_read.exe."
    }

    Copy-Item -LiteralPath $downloadedExe -Destination (Join-Path $binDir "deep_read.exe") -Force
}
finally {
    if (Test-Path $tempZip) {
        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempExtractDir) {
        Remove-Item -LiteralPath $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Binary installation completed." -ForegroundColor Green
Write-Host "Installed to: $(Join-Path $binDir 'deep_read.exe')" -ForegroundColor Green
