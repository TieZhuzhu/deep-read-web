param(
    [Parameter(Mandatory = $true)]
    [string]$HtmlPage,
    [ValidateSet("auto", "msedge", "msedge-dev", "msedge-beta", "chrome", "chrome-dev", "chrome-beta", "chromium", "firefox")]
    [string]$Browser = "auto",
    [int]$AuthTimeout = 60
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

    return $null
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$binaryPath = Join-Path $repoRoot "skills\deep-read-web\bin\deep_read.exe"
$scriptPath = Join-Path $repoRoot "skills\deep-read-web\scripts\deep_read.py"
$arguments = @(
    "--HTML_PAGE", $HtmlPage,
    "--browser", $Browser,
    "--auth-timeout", $AuthTimeout
)

if (Test-Path $binaryPath) {
    Write-Host "Using packaged binary: $binaryPath" -ForegroundColor Cyan
    & $binaryPath @arguments
    exit $LASTEXITCODE
}

$pythonCommand = Get-PythonCommand
if (-not $pythonCommand) {
    throw "deep_read.exe 不存在，且未找到 Python 3。请先运行 .\tools\install_release_binary.ps1 下载发布版，或安装 Python 后再运行。"
}

$runner = $pythonCommand[0]
$prefix = @()
if ($pythonCommand.Length -gt 1) {
    $prefix = $pythonCommand[1..($pythonCommand.Length - 1)]
}

Write-Host "Using Python source mode: $($pythonCommand -join ' ')" -ForegroundColor Cyan
& $runner @prefix $scriptPath @arguments
exit $LASTEXITCODE
