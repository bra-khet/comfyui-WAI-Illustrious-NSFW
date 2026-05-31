<#
.SYNOPSIS
    Thin PowerShell launcher for the personal WAI-Illustrious build helper (Sprint 1).

.DESCRIPTION
    This exists to follow the project convention of providing explicit project launchers
    (see Claude.md "Codex Sandbox Collaboration" guidance).

    It simply forwards to the real bash script running inside WSL (recommended) or
    prints clear instructions if WSL bash is not available in PATH.

    Preferred workflow: open a real Ubuntu terminal in WSL and run the .sh directly.
    This .ps1 is a convenience shim from PowerShell / Windows Terminal.

.EXAMPLE
    .\scripts\build-and-push.ps1 --help
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $RepoRoot 'scripts' 'build-and-push.sh'

Write-Host "=== Personal WAI-Illustrious ComfyUI build launcher (Sprint 1) ===" -ForegroundColor Cyan
Write-Host "Repo root: $RepoRoot" -ForegroundColor DarkGray

# Best path: WSL bash (the actual Ubuntu environment where Docker is usually happiest)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "Detected WSL. Forwarding to Ubuntu bash..." -ForegroundColor Green
    $bashArgs = @('-e', $ScriptPath)
    if ($Arguments) {
        $bashArgs += $Arguments
    }
    & wsl @bashArgs
    exit $LASTEXITCODE
}

# Fallback: Git Bash / MSYS bash if present
$gitBash = "$env:ProgramFiles\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    Write-Host "WSL not found in PATH. Falling back to Git Bash..." -ForegroundColor Yellow
    & $gitBash -lc "bash '$ScriptPath' $($Arguments -join ' ')"
    exit $LASTEXITCODE
}

# Last resort guidance
Write-Host @"
ERROR: Could not find a usable bash environment (WSL or Git Bash).

RECOMMENDED:
  1. Open "Ubuntu" from the Start Menu (your WSL distro).
  2. cd to this repo (the path will be something like /home/youruser/.../comfyui-WAI-Illustrious-NSFW).
  3. Run: ./scripts/build-and-push.sh --help

You can also install WSL if it is missing:
  wsl --install

The real implementation lives in scripts/build-and-push.sh (bash). This .ps1 is only a thin forwarder.
"@ -ForegroundColor Red

exit 1
