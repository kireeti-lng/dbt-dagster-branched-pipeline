# =====================================================================
# setup-env.ps1
#
# Loads and validates the local environment required for dbt.
#
# Usage:
#   . .\scripts\setup-env.ps1
#
# NOTE:
#   Dot-source this script so environment variables remain available:
#
#       . .\scripts\setup-env.ps1
#
# =====================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "           LOCAL ENVIRONMENT SETUP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------
# Repository Root
# ---------------------------------------------------------------------

$RepoRoot = Split-Path $PSScriptRoot -Parent

# ---------------------------------------------------------------------
# Configure Environment Variables
# ---------------------------------------------------------------------

$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\KireetiChennuru\Downloads\lng-geo-play-dbt-github-actions.json"

$env:GCP_PROJECT = "lng-geo-play"

$env:BQ_LOCATION = "US"

$env:DBT_DATASET_PREFIX = "test_"

$env:DBT_PROFILES_DIR = Join-Path $RepoRoot "dbt_dagster_pipeline"

# ---------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------

Write-Host "Validating environment..." -ForegroundColor Yellow
Write-Host ""

# Service Account

if (!(Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {

    throw @"

Service Account JSON not found.

$($env:GOOGLE_APPLICATION_CREDENTIALS)

"@
}

# dbt project

if (!(Test-Path "$($env:DBT_PROFILES_DIR)\dbt_project.yml")) {

    throw "dbt_project.yml not found."
}

# profiles.yml

if (!(Test-Path "$($env:DBT_PROFILES_DIR)\profiles.yml")) {

    throw "profiles.yml not found."
}

# pyproject.toml

if (!(Test-Path "$RepoRoot\pyproject.toml")) {

    throw "pyproject.toml not found."
}

# ---------------------------------------------------------------------
# Display Environment
# ---------------------------------------------------------------------

Write-Host "Environment successfully loaded." -ForegroundColor Green
Write-Host ""

Write-Host "GOOGLE_APPLICATION_CREDENTIALS"
Write-Host "  $($env:GOOGLE_APPLICATION_CREDENTIALS)"
Write-Host ""

Write-Host "GCP_PROJECT"
Write-Host "  $($env:GCP_PROJECT)"
Write-Host ""

Write-Host "BQ_LOCATION"
Write-Host "  $($env:BQ_LOCATION)"
Write-Host ""

Write-Host "DBT_DATASET_PREFIX"
Write-Host "  $($env:DBT_DATASET_PREFIX)"
Write-Host ""

Write-Host "DBT_PROFILES_DIR"
Write-Host "  $($env:DBT_PROFILES_DIR)"
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host " Environment Ready" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""