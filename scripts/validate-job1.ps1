# =====================================================================
# validate-job1.ps1
#
# Local equivalent of GitHub Actions Job 1
#
# Performs:
#   1. Install dependencies
#   2. dbt deps
#   3. dbt parse
#   4. Repository validation
#   5. Pre-commit
#
# =====================================================================

$ErrorActionPreference = "Stop"

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "             JOB 1 - CODE QUALITY GATE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------
# Verify Repository Root
# ---------------------------------------------------------------------

if (!(Test-Path "pyproject.toml")) {

    Write-Host "Run this script from the repository root." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Load Environment
# ---------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($env:GCP_PROJECT)) {

    . .\scripts\setup-env.ps1
}

# ---------------------------------------------------------------------
# Verify Required Files
# ---------------------------------------------------------------------

$requiredFiles = @(
    "scripts\validate_dbt.py",
    ".pre-commit-config.yaml",
    "dbt_dagster_pipeline\dbt_project.yml",
    "dbt_dagster_pipeline\profiles.yml"
)

foreach ($file in $requiredFiles) {

    if (!(Test-Path $file)) {

        Write-Host ""
        Write-Host "Missing required file:" -ForegroundColor Red
        Write-Host "  $file"
        exit 1
    }
}

# ---------------------------------------------------------------------
# Install Dependencies
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Installing project dependencies..." -ForegroundColor Yellow

uv sync

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Dependency installation failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Install dbt Packages
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Installing dbt packages..." -ForegroundColor Yellow

Push-Location dbt_dagster_pipeline

$env:DBT_PROFILES_DIR = "."

uv run dbt deps

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt deps failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Parse dbt
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Running dbt parse..." -ForegroundColor Yellow

uv run dbt parse --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt parse failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Compile dbt
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Compiling dbt blueprints..." -ForegroundColor Yellow

uv run dbt compile --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt compile failed." -ForegroundColor Red
    exit 1
}

Pop-Location



if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt parse failed." -ForegroundColor Red
    exit 1
}

Pop-Location

# ---------------------------------------------------------------------
# Validate Repository
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Running repository validation..." -ForegroundColor Yellow

uv run python scripts/validate_dbt.py

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Repository validation failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Run Pre-Commit
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Running pre-commit hooks..." -ForegroundColor Yellow

uv run pre-commit run --all-files --show-diff-on-failure

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Pre-commit validation failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "             JOB 1 COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host ""
Write-Host "[PASS] Dependencies Installed"
Write-Host "[PASS] dbt Packages Installed"
Write-Host "[PASS] dbt Parse"
Write-Host "[PASS] Repository Validation"
Write-Host "[PASS] Pre-Commit Checks"

Write-Host ""