#Requires -Version 5.1
<#
.SYNOPSIS
    token-diet: Install RTK + tilth + Serena on Windows.

.DESCRIPTION
    Installs the AI token optimization stack and configures for
    Claude Code, Codex CLI, and OpenCode (GitHub Copilot).

.PARAMETER Tool
    Which tool(s) to install: All (default), RTK, tilth, Serena

.PARAMETER SkipDedup
    Skip the Serena/tilth overlap fix.

.PARAMETER VerifyOnly
    Only check current installation status.

.EXAMPLE
    .\Install.ps1                # install all
    .\Install.ps1 -Tool RTK     # RTK only
    .\Install.ps1 -VerifyOnly   # check status
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "RTK", "tilth", "Serena")]
    [string]$Tool = "All",
    [switch]$SkipDedup,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

# --- Configuration -----------------------------------------------------------
$RTK_REPO = "https://github.com/rtk-ai/rtk"
$TILTH_CRATE = "tilth"
$SERENA_REPO = "https://github.com/oraios/serena"

# --- Helpers ------------------------------------------------------------------
function Write-Info   { param($msg) Write-Host "[info]  $msg" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "[ok]    $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "[warn]  $msg" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "[fail]  $msg" -ForegroundColor Red; exit 1 }
function Write-Header { param($msg) Write-Host "`n--- $msg ---`n" -ForegroundColor White }

function Test-Cmd { param([string]$Name) $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

# --- Prerequisites ------------------------------------------------------------
function Ensure-Git {
    if (-not (Test-Cmd "git")) { Write-Fail "git is required. Install from https://git-scm.com" }
    Write-Ok "git found: $(git --version)"
}

function Ensure-Rust {
    if (Test-Cmd "rustup") {
        Write-Ok "Rust found: $(rustc --version 2>$null)"
        rustup update stable --no-self-update 2>$null | Out-Null
    } else {
        Write-Info "Installing Rust toolchain..."
        $installer = Join-Path $env:TEMP "rustup-init.exe"
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $installer -UseBasicParsing
        & $installer -y --default-toolchain stable 2>&1 | Out-Null
        $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
        if (-not (Test-Cmd "rustc")) { Write-Fail "Rust installation failed. Install from https://rustup.rs" }
        Write-Ok "Rust installed: $(rustc --version)"
    }
}

function Ensure-Uv {
    if (Test-Cmd "uv") {
        Write-Ok "uv found: $(uv --version 2>$null)"
    } else {
        Write-Info "Installing uv..."
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
        if (-not (Test-Cmd "uv")) { Write-Fail "uv installation failed. See https://docs.astral.sh/uv/" }
        Write-Ok "uv installed: $(uv --version)"
    }
}

# --- Host detection -----------------------------------------------------------
$script:HasClaude = $false
$script:HasCodex = $false
$script:HasOpenCode = $false

function Detect-Hosts {
    Write-Header "AI Host Detection"
    $script:HasClaude   = Test-Cmd "claude"
    $script:HasCodex    = Test-Cmd "codex"
    $script:HasOpenCode = Test-Cmd "opencode"

    if ($script:HasClaude)   { Write-Ok "Claude Code ... found" } else { Write-Warn "Claude Code ... not found" }
    if ($script:HasCodex)    { Write-Ok "Codex CLI ..... found" } else { Write-Warn "Codex CLI ..... not found" }
    if ($script:HasOpenCode) { Write-Ok "OpenCode ...... found" } else { Write-Warn "OpenCode ...... not found" }

    if (-not $script:HasClaude -and -not $script:HasCodex -and -not $script:HasOpenCode) {
        Write-Warn "No AI host detected. Tools installed but MCP/hook integration skipped."
    }
}

# --- RTK ----------------------------------------------------------------------
function Install-RTK {
    Write-Header "RTK (Rust Token Killer)"

    if ((Test-Cmd "rtk") -and ((rtk gain --help 2>$null); $LASTEXITCODE -eq 0)) {
        Write-Ok "RTK already installed: $(rtk --version 2>$null)"
        Write-Info "Upgrading..."
    } elseif (Test-Cmd "rtk") {
        Write-Warn "Wrong 'rtk' detected. Reinstalling."
    }

    cargo install --git $RTK_REPO --force 2>&1 | Select-Object -Last 5
    Write-Ok "RTK installed: $(rtk --version 2>$null)"

    # Host integration
    if ($script:HasClaude -and $script:HasOpenCode) {
        try { rtk init -g --opencode 2>$null; Write-Ok "RTK: Claude Code + Codex + OpenCode" } catch { Write-Warn "RTK init failed" }
    } elseif ($script:HasClaude) {
        try { rtk init -g 2>$null; Write-Ok "RTK: Claude Code + Codex" } catch { Write-Warn "RTK init failed" }
    }
    if ($script:HasCodex -and -not $script:HasClaude) {
        try { rtk init --codex 2>$null; Write-Ok "RTK: Codex CLI" } catch { Write-Warn "RTK Codex init failed" }
    }
    if ($script:HasOpenCode -and -not $script:HasClaude) {
        try { rtk init -g --opencode 2>$null; Write-Ok "RTK: OpenCode" } catch { Write-Warn "RTK OpenCode init failed" }
    }
}

# --- tilth --------------------------------------------------------------------
function Install-Tilth {
    Write-Header "tilth (smart code reader)"

    if (Test-Cmd "tilth") {
        Write-Ok "tilth already installed"
        Write-Info "Upgrading..."
    }

    cargo install $TILTH_CRATE --force 2>&1 | Select-Object -Last 5
    Write-Ok "tilth installed: $(tilth --version 2>$null)"

    # Host integration
    if ($script:HasClaude) {
        try { tilth install claude-code 2>$null; Write-Ok "tilth MCP: Claude Code" } catch { Write-Warn "tilth MCP: Claude Code failed" }
    }
    if ($script:HasCodex) {
        try { tilth install codex 2>$null; Write-Ok "tilth MCP: Codex CLI" } catch { Write-Warn "tilth MCP: Codex failed" }
    }
    if ($script:HasOpenCode) {
        try { tilth install opencode 2>$null; Write-Ok "tilth MCP: OpenCode" } catch { Write-Warn "tilth MCP: OpenCode failed" }
    }
}

# --- Serena -------------------------------------------------------------------
function Install-Serena {
    Write-Header "Serena (IDE-like symbol navigation)"

    Write-Info "Verifying Serena via uvx..."
    try {
        uvx --from "git+$SERENA_REPO" serena --help 2>$null | Out-Null
        Write-Ok "Serena accessible via uvx"
    } catch {
        Write-Warn "Serena fetch failed. May work on first real invocation."
    }

    # Claude Code
    if ($script:HasClaude) {
        try {
            claude mcp add --scope user serena -- `
                uvx --from "git+$SERENA_REPO" serena start-mcp-server `
                --context=claude-code --project-from-cwd 2>$null
            Write-Ok "Serena MCP: Claude Code"
        } catch { Write-Warn "Serena MCP: Claude Code failed (may already exist)" }
    }

    # Codex CLI
    if ($script:HasCodex) {
        $codexConfig = Join-Path $env:USERPROFILE ".codex\config.toml"
        if ((Test-Path $codexConfig) -and (Select-String -Path $codexConfig -Pattern "serena" -Quiet)) {
            Write-Ok "Serena MCP: Codex CLI (already configured)"
        } else {
            $codexDir = Join-Path $env:USERPROFILE ".codex"
            if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Path $codexDir -Force | Out-Null }
            $tomlBlock = @"

# Serena MCP server (added by token-diet)
[mcp_servers.serena]
command = "uvx"
args = ["--from", "git+$SERENA_REPO", "serena", "start-mcp-server", "--context=codex", "--project-from-cwd"]
"@
            Add-Content -Path $codexConfig -Value $tomlBlock -Encoding UTF8
            Write-Ok "Serena MCP: Codex CLI (appended to $codexConfig)"
        }
    }

    # OpenCode
    if ($script:HasOpenCode) {
        Write-Warn "Serena MCP: OpenCode requires manual config"
        Write-Info "  Add serena to MCP servers with: uvx --from git+$SERENA_REPO serena start-mcp-server --project-from-cwd"
    }
}

# --- Overlap fix --------------------------------------------------------------
function Configure-Dedup {
    Write-Header "Overlap fix (Serena dedup)"

    if (-not (Test-Cmd "tilth")) {
        Write-Info "tilth not installed -- skipping dedup"
        return
    }

    $templateDir = Join-Path $env:USERPROFILE ".config\serena"
    if (-not (Test-Path $templateDir)) { New-Item -ItemType Directory -Path $templateDir -Force | Out-Null }

    $templateFile = Join-Path $templateDir "project.local.template.yml"
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $configSource = Join-Path (Split-Path -Parent $scriptDir) "config\serena-dedup.template.yml"

    if (Test-Path $configSource) {
        Copy-Item $configSource $templateFile -Force
    } else {
        @"
# Serena project.local.yml -- overlap fix when tilth is also installed
context: claude-code
disabled_tools:
  - get_symbols_overview
  - find_symbol
  - read_file
"@ | Set-Content -Path $templateFile -Encoding UTF8
    }

    Write-Ok "Dedup template: $templateFile"
    Write-Info "Apply per project: Copy-Item '$templateFile' '<project>\project.local.yml'"
}

# --- Verification -------------------------------------------------------------
function Verify-Stack {
    Write-Header "Token Stack Verification"

    $allOk = $true

    if ((Test-Cmd "rtk") -and ((rtk gain --help 2>$null); $LASTEXITCODE -eq 0)) {
        Write-Ok "RTK ............. $(rtk --version 2>$null)"
    } else { Write-Warn "RTK ............. not installed or wrong version"; $allOk = $false }

    if (Test-Cmd "tilth") {
        Write-Ok "tilth ........... $(tilth --version 2>$null)"
    } else { Write-Warn "tilth ........... not installed"; $allOk = $false }

    if (Test-Cmd "uv") {
        Write-Ok "Serena (via uv) . $(uv --version 2>$null)"
    } else { Write-Warn "Serena (uv) ..... not installed"; $allOk = $false }

    Write-Host ""
    if (Test-Cmd "claude")   { Write-Ok "Claude Code ..... available" } else { Write-Warn "Claude Code ..... not found" }
    if (Test-Cmd "codex")    { Write-Ok "Codex CLI ....... available" } else { Write-Warn "Codex CLI ....... not found" }
    if (Test-Cmd "opencode") { Write-Ok "OpenCode ........ available" } else { Write-Warn "OpenCode ........ not found" }

    Write-Host ""
    if ($allOk) { Write-Ok "All tools installed. Token diet active." }
    else        { Write-Warn "Some tools missing. Re-run to install." }

    Write-Host @"

  +--------------------------------------------------+
  |          Claude Code / Codex / OpenCode           |
  +--------------------------------------------------+
           |                |                |
      Code reading     Refactoring     Command output
           |                |                |
      +--------+      +---------+      +--------+
      | tilth  |      | Serena  |      |  RTK   |
      | (fast) |      |  (deep) |      | (filter)|
      +--------+      +---------+      +--------+
      tree-sitter        LSP           regex/truncate

"@
}

# --- Main ---------------------------------------------------------------------
Write-Host "`n=== token-diet ===" -ForegroundColor White
Write-Host "    RTK + tilth + Serena`n" -ForegroundColor White

if ($VerifyOnly) { Verify-Stack; exit 0 }

$doRtk    = $Tool -eq "All" -or $Tool -eq "RTK"
$doTilth  = $Tool -eq "All" -or $Tool -eq "tilth"
$doSerena = $Tool -eq "All" -or $Tool -eq "Serena"

Write-Header "Prerequisites"
Ensure-Git
if ($doRtk -or $doTilth) { Ensure-Rust }
if ($doSerena) { Ensure-Uv }

Detect-Hosts

if ($doRtk)    { Install-RTK }
if ($doTilth)  { Install-Tilth }
if ($doSerena) { Install-Serena }

if (-not $SkipDedup -and $doTilth -and $doSerena) { Configure-Dedup }

Verify-Stack
