param(
    [switch]$RunNetworkSmoke
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

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "skills\deep-read-web\scripts\deep_read.py"
$pythonCommand = Get-PythonCommand
$runner = $pythonCommand[0]
$prefix = @()
if ($pythonCommand.Length -gt 1) {
    $prefix = $pythonCommand[1..($pythonCommand.Length - 1)]
}

function Invoke-Python {
    param([string[]]$Arguments)
    return (Invoke-PythonAndCapture -Arguments $Arguments).ExitCode
}

function Invoke-PythonAndCapture {
    param([string[]]$Arguments)
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $argumentList = @($prefix + $Arguments)
        $process = Start-Process `
            -FilePath $runner `
            -ArgumentList $argumentList `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        return @{
            Output = (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue)
            Error = (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)
            ExitCode = $process.ExitCode
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Compiling Python script..." -ForegroundColor Cyan
$compileExit = Invoke-Python @("-m", "py_compile", $scriptPath)
if ($compileExit -ne 0) {
    throw "py_compile failed with exit code $compileExit."
}

Write-Host "Checking invalid URL handling..." -ForegroundColor Cyan
$invalidUrlResult = Invoke-PythonAndCapture @($scriptPath, "--HTML_PAGE", "not-a-url")
if ($invalidUrlResult.ExitCode -ne 2) {
    throw "Expected exit code 2 for invalid URL, got $($invalidUrlResult.ExitCode)."
}

Write-Host "Checking help output..." -ForegroundColor Cyan
$helpResult = Invoke-PythonAndCapture @($scriptPath, "--help")
if ($helpResult.ExitCode -ne 0) {
    throw "Help command failed with exit code $($helpResult.ExitCode)."
}

if ($RunNetworkSmoke) {
    Write-Host "Running public page smoke test..." -ForegroundColor Cyan
    $smokeResult = Invoke-PythonAndCapture @($scriptPath, "--HTML_PAGE", "https://example.com", "--browser", "auto")
    if ($smokeResult.ExitCode -ne 0) {
        throw "Public page smoke test failed with exit code $($smokeResult.ExitCode)."
    }
    if (($smokeResult.Output -join "`n") -notmatch "<html") {
        throw "Public page smoke test did not return HTML."
    }
}

Write-Host "Verification completed." -ForegroundColor Green
