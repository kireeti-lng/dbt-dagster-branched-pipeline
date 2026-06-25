Write-Host ""
Write-Host "============================================="
Write-Host "     Job 2 - dbt Validation"
Write-Host "============================================="
Write-Host ""

#-------------------------------------------------------
# Verify required environment variables
#-------------------------------------------------------

$required = @(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GCP_PROJECT",
    "BQ_LOCATION",
    "DBT_DATASET_PREFIX"
)

foreach ($var in $required) {

    if ([string]::IsNullOrWhiteSpace($env:$var)) {
        Write-Host ""
        Write-Host "ERROR: Environment variable '$var' is not set."
        exit 1
    }
}

Write-Host "Environment variables verified."
Write-Host ""

#-------------------------------------------------------
# Verify Service Account File
#-------------------------------------------------------

if (!(Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {

    Write-Host "ERROR:"
    Write-Host "Service Account JSON not found."

    Write-Host $env:GOOGLE_APPLICATION_CREDENTIALS

    exit 1
}

Write-Host "Service Account JSON found."
Write-Host ""

#-------------------------------------------------------
# Install Dependencies
#-------------------------------------------------------

Write-Host "Installing project dependencies..."
uv sync --group dev

if ($LASTEXITCODE -ne 0) {
    exit 1
}

Write-Host ""
Write-Host "Dependencies installed."
Write-Host ""

#-------------------------------------------------------
# Move into dbt project
#-------------------------------------------------------

Push-Location dbt_dagster_pipeline

#-------------------------------------------------------
# dbt deps
#-------------------------------------------------------

Write-Host "Running dbt deps..."

dbt deps

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    exit 1
}

Write-Host ""
Write-Host "dbt deps completed."
Write-Host ""

#-------------------------------------------------------
# dbt debug
#-------------------------------------------------------

Write-Host "Running dbt debug..."

dbt debug --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    exit 1
}

Write-Host ""
Write-Host "dbt debug successful."
Write-Host ""

#-------------------------------------------------------
# dbt build
#-------------------------------------------------------

Write-Host "Running dbt build..."

dbt build --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location

    exit 1
}

Write-Host ""
Write-Host "dbt build successful."
Write-Host ""

#-------------------------------------------------------
# Return
#-------------------------------------------------------

Pop-Location

Write-Host ""
Write-Host "============================================="
Write-Host "Job 2 PASSED"
Write-Host "============================================="