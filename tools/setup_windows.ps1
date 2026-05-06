param(
    [switch]$InstallFirefox
)

$ErrorActionPreference = "Stop"

function Get-PythonCommand {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @("py", "-3")
    }

    if (Get-Command python -ErrorAction SilentlyContinue) {
        return @("python")
    }

    throw "Python not found. Please install Python 3 first."
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
}

$pythonCommand = Get-PythonCommand

Write-Host "Using Python command: $($pythonCommand -join ' ')" -ForegroundColor Cyan
Invoke-PythonModule -PythonCommand $pythonCommand -Arguments @("-m", "pip", "install", "playwright")

$browserArgs = @("-m", "playwright", "install", "chromium")
if ($InstallFirefox) {
    $browserArgs += "firefox"
}

Invoke-PythonModule -PythonCommand $pythonCommand -Arguments $browserArgs

Write-Host "Playwright setup completed." -ForegroundColor Green
