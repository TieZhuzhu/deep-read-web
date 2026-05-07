param(
    [ValidateSet("small", "full")]
    [string]$Flavor = "small"
)

$ErrorActionPreference = "Stop"

function Get-PythonCommand {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py -and $py.Source) {
        return @($py.Source, "-3")
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python -and $python.Source) {
        return @($python.Source)
    }

    throw "Python not found. Please install Python 3 first."
}

function Invoke-Python {
    param(
        [string[]]$PythonCommand,
        [string[]]$Arguments
    )

    $runner = $PythonCommand[0]
    $prefix = @()
    if ($PythonCommand.Length -gt 1) {
        $prefix = $PythonCommand[1..($PythonCommand.Length - 1)]
    }

    & $runner @prefix @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $runner $($prefix + $Arguments -join ' ')"
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "skills\deep-read-web\scripts\deep_read.py"
$binDir = Join-Path $repoRoot "skills\deep-read-web\bin"
$distDir = Join-Path $repoRoot "dist"
$pyiWorkDir = Join-Path $repoRoot "build\pyinstaller"
$pyiSpecDir = Join-Path $repoRoot "build\spec"
$exePath = Join-Path $binDir "deep_read.exe"
$pythonCommand = Get-PythonCommand
$shouldBundleChromium = $Flavor -eq "full"
$archiveName = if ($shouldBundleChromium) {
    "deep_read-windows-x64-with-chromium.zip"
}
else {
    "deep_read-windows-x64.zip"
}
$zipPath = Join-Path $distDir $archiveName

New-Item -ItemType Directory -Force -Path $binDir | Out-Null
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
New-Item -ItemType Directory -Force -Path $pyiWorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $pyiSpecDir | Out-Null

Write-Host "Using Python command: $($pythonCommand -join ' ')" -ForegroundColor Cyan
Write-Host "Build flavor: $Flavor" -ForegroundColor Cyan
Write-Host "Installing build dependencies..." -ForegroundColor Cyan
Invoke-Python -PythonCommand $pythonCommand -Arguments @("-m", "pip", "install", "playwright", "pyinstaller")

if ($shouldBundleChromium) {
    Write-Host "Bundling Playwright Chromium into the packaged build..." -ForegroundColor Cyan
    $env:PLAYWRIGHT_BROWSERS_PATH = "0"
    Invoke-Python -PythonCommand $pythonCommand -Arguments @("-m", "playwright", "install", "chromium")
}
else {
    Remove-Item Env:PLAYWRIGHT_BROWSERS_PATH -ErrorAction SilentlyContinue
}

if (Test-Path $exePath) {
    Remove-Item -LiteralPath $exePath -Force
}

if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Write-Host "Building deep_read.exe..." -ForegroundColor Cyan
Invoke-Python -PythonCommand $pythonCommand -Arguments @(
    "-m", "PyInstaller",
    "--noconfirm",
    "--clean",
    "--onefile",
    "--name", "deep_read",
    "--collect-all", "playwright",
    "--hidden-import", "playwright.sync_api",
    "--hidden-import", "playwright.async_api",
    "--distpath", $binDir,
    "--workpath", $pyiWorkDir,
    "--specpath", $pyiSpecDir,
    $scriptPath
)

if (-not (Test-Path $exePath)) {
    throw "Build completed but deep_read.exe was not found at $exePath"
}

Write-Host "Creating release archive..." -ForegroundColor Cyan
Compress-Archive -LiteralPath $exePath -DestinationPath $zipPath -Force

Write-Host "Build completed." -ForegroundColor Green
Write-Host "Executable: $exePath" -ForegroundColor Green
Write-Host "Archive: $zipPath" -ForegroundColor Green
