# install.ps1: cc-deck Windows installer
# https://github.com/sysnet4admin/cc-deck
#
# Run once:  .\install.ps1
# Then:      . $PROFILE

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = $PSScriptRoot

Write-Host "Installing cc-deck..."
Write-Host ""

# Check Python
$python = $null
if (Get-Command python3 -ErrorAction SilentlyContinue) { $python = "python3" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $python = "python" }

if (-not $python) {
    Write-Host "Error: python not found."
    Write-Host "  Install from https://python.org or: winget install Python.Python.3"
    exit 1
}
Write-Host "python : OK ($python)"

# Check fzf
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Write-Host "fzf    : OK"
} else {
    Write-Host "fzf    : NOT FOUND (TUI disabled)"
    Write-Host "  Install: winget install junegunn.fzf"
    Write-Host ""
}

# Ensure profile directory exists
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

# Add dot-source line to PowerShell profile
$sourceLine = ". `"$SCRIPT_DIR\cc-deck.ps1`""
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -and $profileContent.Contains($sourceLine)) {
    Write-Host "profile: already installed in $PROFILE"
} else {
    Add-Content -Path $PROFILE -Value ""
    Add-Content -Path $PROFILE -Value "# cc-deck: Claude Code session browser"
    Add-Content -Path $PROFILE -Value $sourceLine
    Write-Host "profile: added to $PROFILE"
}

Write-Host ""
Write-Host "Done! Reload your profile:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Then type:  cc-deck"
