param(
    [string]$Repo = "TieZhuzhu/deep-read-web",
    [ValidateSet("auto", "small", "full")]
    [string]$Flavor = "auto",
    [string]$Tag
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repoRoot "skills\deep-read-web\scripts\install_binary.ps1"

if (-not (Test-Path $installerPath)) {
    throw "Skill installer script not found: $installerPath"
}

& $installerPath -Repo $Repo -Flavor $Flavor -Tag $Tag
exit $LASTEXITCODE
