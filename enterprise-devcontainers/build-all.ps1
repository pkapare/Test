# =============================================================================
# Build all images top to bottom in dependency order.
#
# Usage:
#   .\build-all.ps1                                    # Build all (universal variant)
#   .\build-all.ps1 -Variant all                       # Build ALL IDE variants
#   .\build-all.ps1 -Variant serveweb                  # Build only serveweb variant
#   .\build-all.ps1 -SkipPush -SkipScan                # Local build only
#   .\build-all.ps1 -Tag "v1.2.3"                      # Custom tag
#   .\build-all.ps1 -Registry "myregistry.io/devctrs"  # Custom registry
#   .\build-all.ps1 -SmokeTest                         # Run smoke tests after build
# =============================================================================
param(
    [string]$Registry = "",
    [switch]$SkipPush,
    [switch]$SkipScan,
    [switch]$SmokeTest,
    [string]$Tag = "",
    [ValidateSet("universal", "serveweb", "codeserver", "jetbrains", "headless", "all")]
    [string]$Variant = "universal"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$totalStart = Get-Date
$builtImages = @()

# Load centralized constants
$constantsFile = Join-Path $root "config\constants.ps1"
if (Test-Path $constantsFile) {
    . $constantsFile
    # Use constants as defaults (param values override)
    if (-not $PSBoundParameters.ContainsKey('Registry')) {
        $Registry = $script:REGISTRY
    }
}
if (-not $Registry) { $Registry = "kapconreg.azurecr.io/devcontainers" }

# ─── Auto-generate tag from git if not specified ─────────────────────────────
if (-not $Tag) {
    $gitSha = git -C $root rev-parse --short HEAD 2>$null
    $dateTag = Get-Date -Format "yyyyMMdd"
    if ($gitSha) {
        $Tag = "$dateTag-$gitSha"
    } else {
        $Tag = $dateTag
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building All Images (Top to Bottom)"   -ForegroundColor Cyan
Write-Host "  Registry:  $Registry"                   -ForegroundColor Cyan
Write-Host "  Tag:       $Tag"                        -ForegroundColor Cyan
Write-Host "  Variant:   $Variant"                    -ForegroundColor Cyan
Write-Host "  SmokeTest: $SmokeTest"                  -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ─── Authenticate ────────────────────────────────────────────────────────────
if (-not $SkipPush) {
    Write-Host "`n--- Authenticating with ACR ---" -ForegroundColor Yellow
    $acrName = if ($script:ACR_NAME) { $script:ACR_NAME } else { "kapconreg" }
    az acr login --name $acrName
    if ($LASTEXITCODE -ne 0) { throw "ACR login failed" }
}

# ─── Build function ──────────────────────────────────────────────────────────
function Build-Image {
    param(
        [string]$Name,
        [string]$Context,
        [string]$Tier
    )
    $imageLatest = "$Registry/${Name}:latest"
    $imageTagged = "$Registry/${Name}:$Tag"
    $start = Get-Date

    Write-Host "`n--- [$Tier] Building $Name ---" -ForegroundColor Yellow
    docker build -t $imageLatest -t $imageTagged $Context
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed: $Name" }

    $elapsed = ((Get-Date) - $start).TotalSeconds
    Write-Host "    Built in $([math]::Round($elapsed))s" -ForegroundColor DarkGray

    # Trivy vulnerability scan
    if (-not $SkipScan) {
        Write-Host "--- [$Tier] Scanning $Name ---" -ForegroundColor Yellow
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock `
            aquasec/trivy:latest image --exit-code 1 --severity CRITICAL $imageLatest
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN] Trivy found CRITICAL vulnerabilities in $Name" -ForegroundColor Red
        }
    }

    # Push to registry
    if (-not $SkipPush) {
        Write-Host "--- [$Tier] Pushing $Name ---" -ForegroundColor Yellow
        docker push $imageLatest
        if ($LASTEXITCODE -ne 0) { throw "Docker push failed: $Name (latest)" }
        docker push $imageTagged
        if ($LASTEXITCODE -ne 0) { throw "Docker push failed: $Name ($Tag)" }
    }

    Write-Host "--- [$Tier] Done: $Name ---" -ForegroundColor Green
    $script:builtImages += "$Registry/${Name}:$Tag"
}

# ─── Smoke test function ─────────────────────────────────────────────────────
function Smoke-Test {
    param(
        [string]$Name,
        [string]$Commands
    )
    if (-not $SmokeTest) { return }

    Write-Host "--- Smoke testing $Name ---" -ForegroundColor Magenta
    $image = "$Registry/${Name}:latest"
    docker run --rm $image bash -c $Commands
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Smoke test failed: $Name" -ForegroundColor Red
        throw "Smoke test failed: $Name"
    }
    Write-Host "[PASS] Smoke test passed: $Name" -ForegroundColor Green
}

# =============================================================================
# TIER 0 — Core
# =============================================================================
Build-Image -Name "org-base-core" -Context "$root\org\org-base-core" -Tier "Tier 0"
Smoke-Test -Name "org-base-core" -Commands "claude --version && git --version && jq --version && rg --version"

# =============================================================================
# TIER 1 — IDE Variants
# =============================================================================
$variantMap = @{
    "universal"  = @{ Name = "org-base-universal";        Context = "$root\org\org-base-universal" }
    "serveweb"   = @{ Name = "org-base-vscode-serveweb";  Context = "$root\org\org-base-vscode-serveweb" }
    "codeserver"  = @{ Name = "org-base-vscode-codeserver"; Context = "$root\org\org-base-vscode-codeserver" }
    "jetbrains"  = @{ Name = "org-base-jetbrains";        Context = "$root\org\org-base-jetbrains" }
    "headless"   = @{ Name = "org-base-headless";         Context = "$root\org\org-base-headless" }
}

$smokeMap = @{
    "universal"  = "claude --version && code --version && which sshd"
    "serveweb"   = "claude --version && code --version"
    "codeserver"  = "claude --version && which code-server"
    "jetbrains"  = "claude --version && which sshd"
    "headless"   = "claude --version"
}

if ($Variant -eq "all") {
    foreach ($v in $variantMap.Keys) {
        $entry = $variantMap[$v]
        Build-Image -Name $entry.Name -Context $entry.Context -Tier "Tier 1 ($v)"
        Smoke-Test -Name $entry.Name -Commands $smokeMap[$v]
    }
} else {
    $entry = $variantMap[$Variant]
    Build-Image -Name $entry.Name -Context $entry.Context -Tier "Tier 1 ($Variant)"
    Smoke-Test -Name $entry.Name -Commands $smokeMap[$Variant]
}

# =============================================================================
# TIER 2 — LOB / Stack
# =============================================================================
Build-Image -Name "lob-dotnet" -Context "$root\lob-dotnet" -Tier "Tier 2"
Build-Image -Name "lob-nodejs" -Context "$root\lob-nodejs" -Tier "Tier 2"

Smoke-Test -Name "lob-dotnet" -Commands "claude --version && dotnet --version && dotnet tool list -g"
Smoke-Test -Name "lob-nodejs" -Commands "claude --version && node --version && pnpm --version"

# =============================================================================
# TIER 3 — Projects
# =============================================================================
Build-Image -Name "project-one"   -Context "$root\projects\project-one"   -Tier "Tier 3"
Build-Image -Name "project-two"   -Context "$root\projects\project-two"   -Tier "Tier 3"
Build-Image -Name "project-three" -Context "$root\projects\project-three" -Tier "Tier 3"

Smoke-Test -Name "project-one" -Commands @"
claude --version && dotnet --version && \
cat ~/.claude/CLAUDE.md | head -5 && \
ls ~/.claude/commands/ && \
test -f ~/.claude.json && echo 'MCP config exists'
"@

Smoke-Test -Name "project-two" -Commands @"
claude --version && dotnet --version && \
cat ~/.claude/CLAUDE.md | head -5 && \
ls ~/.claude/commands/ && \
test -f ~/.claude.json && echo 'MCP config exists'
"@

Smoke-Test -Name "project-three" -Commands @"
claude --version && dotnet --version && \
cat ~/.claude/CLAUDE.md | head -5 && \
ls ~/.claude/commands/ && \
test -f ~/.claude.json && echo 'MCP config exists'
"@

# =============================================================================
# Summary
# =============================================================================
$totalElapsed = ((Get-Date) - $totalStart).TotalSeconds

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All images built successfully!"          -ForegroundColor Green
Write-Host "  Total time: $([math]::Round($totalElapsed))s" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Built images (tagged: latest + $Tag):"
foreach ($img in $builtImages) {
    Write-Host "  $img"
}
Write-Host ""
if ($SkipPush) {
    Write-Host "  [INFO] Push skipped (use without -SkipPush to push)" -ForegroundColor Yellow
}
if ($SkipScan) {
    Write-Host "  [INFO] Trivy scan skipped (use without -SkipScan to scan)" -ForegroundColor Yellow
}
if (-not $SmokeTest) {
    Write-Host "  [INFO] Smoke tests skipped (use -SmokeTest to enable)" -ForegroundColor Yellow
}
Write-Host ""
