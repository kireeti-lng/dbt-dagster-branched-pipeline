# =====================================================================
# setup-env.ps1
#
# Loads all environment variables required for local dbt validation.
#
# Usage:
#   .\scripts\setup-env.ps1
# =====================================================================

Write-Host ""
Write-Host "=========================================="
Write-Host " Loading Local Environment"
Write-Host "=========================================="
Write-Host ""

# ---------------------------------------------------------------------
# UPDATE THESE VALUES FOR YOUR MACHINE
# ---------------------------------------------------------------------

$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\KireetiChennuru\Downloads\lng-geo-play-dbt-github-actions.json"

$env:GCP_PROJECT = "lng-geo-play"

$env:BQ_LOCATION = "US"

$env:DBT_DATASET_PREFIX = "test_"

# Optional (if your project uses these)

$env:DBT_PROFILES_DIR = (Join-Path (Get-Location) "dbt_dagster_pipeline")

# ---------------------------------------------------------------------
# Validate Service Account File
# ---------------------------------------------------------------------

if (!(Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {

    Write-Host "ERROR:"
    Write-Host ""
    Write-Host "Service Account JSON not found."
    Write-Host ""
    Write-Host $env:GOOGLE_APPLICATION_CREDENTIALS
    exit 1
}

# ---------------------------------------------------------------------
# Display Configuration
# ---------------------------------------------------------------------

Write-Host "Environment successfully loaded."
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

Write-Host "=========================================="
Write-Host " Environment Ready"
Write-Host "=========================================="