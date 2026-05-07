param(
    [switch]$InstallChromium,
    [switch]$InstallFirefox
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

function Invoke-PythonModule {
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
$binaryPath = Join-Path $repoRoot "skills\deep-read-web\bin\deep_read.exe"
$pythonCommand = Get-PythonCommand

if (-not $pythonCommand) {
    if (Test-Path $binaryPath) {
        Write-Host "已找到 deep_read.exe，当前环境可直接使用二进制模式，无需安装 Python 依赖。" -ForegroundColor Green
        if ($InstallChromium -or $InstallFirefox) {
            Write-Warning "无 Python 模式下无法通过本脚本安装 Playwright 浏览器运行时。请改用源码模式，或直接安装带 Chromium 的完整发布版。"
        }
        exit 0
    }

    throw "未找到 Python 3，且本地也没有 deep_read.exe。请先运行 .\tools\install_release_binary.ps1 下载发布版，或安装 Python 3 后再执行本脚本。"
}

Write-Host "Using Python command: $($pythonCommand -join ' ')" -ForegroundColor Cyan
Invoke-PythonModule -PythonCommand $pythonCommand -Arguments @("-m", "pip", "install", "playwright")

if ($InstallChromium -or $InstallFirefox) {
    $browserArgs = @("-m", "playwright", "install")
    if ($InstallChromium) {
        $browserArgs += "chromium"
    }
    if ($InstallFirefox) {
        $browserArgs += "firefox"
    }

    Invoke-PythonModule -PythonCommand $pythonCommand -Arguments $browserArgs
}

Write-Host "Playwright setup completed." -ForegroundColor Green
