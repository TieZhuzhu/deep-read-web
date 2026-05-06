param(
    [Parameter(Mandatory = $true)]
    [string]$HtmlPage,
    [ValidateSet("auto", "msedge", "msedge-dev", "msedge-beta", "chrome", "chrome-dev", "chrome-beta", "chromium", "firefox")]
    [string]$Browser = "auto",
    [int]$AuthTimeout = 60
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
$arguments = @(
    $scriptPath,
    "--HTML_PAGE", $HtmlPage,
    "--browser", $Browser,
    "--auth-timeout", $AuthTimeout
)

& $runner @prefix @arguments
exit $LASTEXITCODE
