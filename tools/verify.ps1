param(
    [switch]$RunNetworkSmoke,
    [switch]$UseBinary
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

function Invoke-CommandAndCapture {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $Arguments `
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

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "skills\deep-read-web\scripts\deep_read.py"
$binaryPath = Join-Path $repoRoot "skills\deep-read-web\bin\deep_read.exe"

$runner = $null
$prefixArguments = @()
$baseArguments = @()

if ($UseBinary) {
    if (-not (Test-Path $binaryPath)) {
        throw "Binary not found: $binaryPath"
    }

    $runner = $binaryPath
    Write-Host "Using packaged binary: $binaryPath" -ForegroundColor DarkGray
}
else {
    $pythonCommand = Get-PythonCommand
    $runner = $pythonCommand[0]
    if ($pythonCommand.Length -gt 1) {
        $prefixArguments = $pythonCommand[1..($pythonCommand.Length - 1)]
    }
    $baseArguments = @($scriptPath)

    Write-Host ("Using Python command: " + (($pythonCommand | ForEach-Object { $_ }) -join " ")) -ForegroundColor DarkGray
}

function Invoke-DeepRead {
    param([string[]]$Arguments)
    return Invoke-CommandAndCapture -FilePath $runner -Arguments @($prefixArguments + $baseArguments + $Arguments)
}

if (-not $UseBinary) {
    Write-Host "Compiling Python script..." -ForegroundColor Cyan
    $compileResult = Invoke-CommandAndCapture -FilePath $runner -Arguments @($prefixArguments + @("-m", "py_compile", $scriptPath))
    if ($compileResult.ExitCode -ne 0) {
        throw "py_compile failed with exit code $($compileResult.ExitCode)."
    }
}

Write-Host "Checking invalid URL handling..." -ForegroundColor Cyan
$invalidUrlResult = Invoke-DeepRead @("--HTML_PAGE", "not-a-url")
if ($invalidUrlResult.ExitCode -ne 2) {
    throw "Expected exit code 2 for invalid URL, got $($invalidUrlResult.ExitCode)."
}

Write-Host "Checking help output..." -ForegroundColor Cyan
$helpResult = Invoke-DeepRead @("--help")
if ($helpResult.ExitCode -ne 0) {
    throw "Help command failed with exit code $($helpResult.ExitCode)."
}

if ($RunNetworkSmoke) {
    Write-Host "Running public page smoke test..." -ForegroundColor Cyan
    $smokeResult = Invoke-DeepRead @("--HTML_PAGE", "https://example.com", "--browser", "auto")
    if ($smokeResult.ExitCode -ne 0) {
        throw "Public page smoke test failed with exit code $($smokeResult.ExitCode)."
    }
    if (($smokeResult.Output -join "`n") -notmatch "<html") {
        throw "Public page smoke test did not return HTML."
    }
}

Write-Host "Verification completed." -ForegroundColor Green
