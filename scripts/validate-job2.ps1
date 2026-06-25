# =====================================================================
# validate-job2.ps1
#
# Local equivalent of GitHub Actions Job 2
#
# Performs:
#   1. Environment Validation
#   2. dbt Debug
#   3. dbt Build
#
# =====================================================================

$ErrorActionPreference = "Stop"

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "              JOB 2 - DBT VALIDATION" -ForegroundColor Cyan
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
# Validate Required Environment Variables
# ---------------------------------------------------------------------

$required = @(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GCP_PROJECT",
    "BQ_LOCATION",
    "DBT_DATASET_PREFIX",
    "DBT_PROFILES_DIR"
)

foreach ($var in $required) {

    $value = [Environment]::GetEnvironmentVariable($var)

    if ([string]::IsNullOrWhiteSpace($value)) {

        Write-Host ""
        Write-Host "Missing environment variable: $var" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Environment validation passed." -ForegroundColor Green

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
# Switch to dbt Project
# ---------------------------------------------------------------------

Push-Location dbt_dagster_pipeline

$env:DBT_PROFILES_DIR = "."

# ---------------------------------------------------------------------
# Install dbt Packages
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Installing dbt packages..." -ForegroundColor Yellow

uv run dbt deps

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt deps failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# dbt Debug
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Running dbt debug..." -ForegroundColor Yellow

uv run dbt debug --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt debug failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# dbt Build
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Running dbt build..." -ForegroundColor Yellow

uv run dbt build --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    Write-Host ""
    Write-Host "dbt build failed." -ForegroundColor Red
    exit 1
}

Pop-Location

# ---------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "           JOB 2 COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host ""
Write-Host "[PASS] Environment Validation"
Write-Host "[PASS] Dependency Installation"
Write-Host "[PASS] dbt Packages Installed"
Write-Host "[PASS] dbt Debug"
Write-Host "[PASS] dbt Build"

Write-Host ""