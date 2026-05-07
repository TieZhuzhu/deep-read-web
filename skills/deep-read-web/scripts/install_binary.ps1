param(
    [string]$Repo = "TieZhuzhu/deep-read-web",
    [ValidateSet("auto", "small", "full")]
    [string]$Flavor = "auto",
    [string]$Tag
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-GitHubHeaders {
    $headers = @{
        "User-Agent" = "deep-read-web-installer"
    }

    $token = $env:GITHUB_TOKEN
    if (-not $token) {
        $token = $env:GH_TOKEN
    }

    if ($token) {
        $headers["Authorization"] = "Bearer $token"
    }

    return $headers
}

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

$skillRoot = Split-Path -Parent $PSScriptRoot
$binDir = Join-Path $skillRoot "bin"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

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

$downloadUrl = if ($Tag) {
    "https://github.com/$Repo/releases/download/$Tag/$assetName"
}
else {
    "https://github.com/$Repo/releases/latest/download/$assetName"
}
$headers = Get-GitHubHeaders

$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("deep-read-web-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
$tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("deep-read-web-" + [System.Guid]::NewGuid().ToString("N"))

try {
    Write-Host "Resolved flavor: $resolvedFlavor" -ForegroundColor Cyan
    Write-Host "Downloading $assetName from $downloadUrl ..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -Headers $headers
    }
    catch {
        $message = $_.Exception.Message
        if ($message -match "404") {
            if ($Tag) {
                throw "Release asset '$assetName' was not found for tag '$Tag' in $Repo."
            }

            throw "Latest release asset '$assetName' was not found in $Repo. Please confirm the GitHub Release has been published."
        }

        if ($message -match "403" -or $message -match "rate limit") {
            throw "GitHub download was rate-limited. Set GITHUB_TOKEN or GH_TOKEN and retry."
        }

        throw
    }

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
