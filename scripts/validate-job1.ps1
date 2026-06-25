# =====================================================================
# Job 1 - Code Quality Gate
# Simulates GitHub Actions Job 1 locally
# =====================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================="
Write-Host "            JOB 1 - CODE QUALITY GATE"
Write-Host "============================================================="
Write-Host ""

# ------------------------------------------------------------
# Verify Repository
# ------------------------------------------------------------

if (!(Test-Path "pyproject.toml")) {

    Write-Host "ERROR: Run this script from the repository root."
    exit 1
}

# ------------------------------------------------------------
# Verify Environment Variables
# ------------------------------------------------------------

Write-Host "Checking Environment Variables..."

$required = @(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GCP_PROJECT",
    "BQ_LOCATION",
    "DBT_DATASET_PREFIX"
)

foreach ($var in $required) {

    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($var))) {

        Write-Host ""
        Write-Host "ERROR: Environment variable '$var' is not set."
        exit 1
    }
}

Write-Host "Environment variables verified."
Write-Host ""

# ------------------------------------------------------------
# Verify Service Account
# ------------------------------------------------------------

Write-Host "Checking Service Account..."

if (!(Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {

    Write-Host ""
    Write-Host "ERROR: Service Account JSON not found."

    Write-Host $env:GOOGLE_APPLICATION_CREDENTIALS

    exit 1
}

Write-Host "Service Account found."
Write-Host ""

# ------------------------------------------------------------
# Install Dependencies
# ------------------------------------------------------------

Write-Host "Installing project dependencies..."

uv sync --group dev

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Dependency installation failed."

    exit 1
}

Write-Host "Dependencies installed."
Write-Host ""

# ------------------------------------------------------------
# Move into dbt Project
# ------------------------------------------------------------

Push-Location dbt_dagster_pipeline

# ------------------------------------------------------------
# Install dbt Packages
# ------------------------------------------------------------

Write-Host "Running dbt deps..."

dbt deps

if ($LASTEXITCODE -ne 0) {

    Pop-Location
    exit 1
}

Write-Host "dbt deps completed."
Write-Host ""

# ------------------------------------------------------------
# Generate Manifest
# ------------------------------------------------------------

Write-Host "Generating manifest..."

dbt parse --target ci

if ($LASTEXITCODE -ne 0) {

    Pop-Location
    exit 1
}

Write-Host "Manifest generated."
Write-Host ""

# ------------------------------------------------------------
# Verify Manifest
# ------------------------------------------------------------

if (!(Test-Path "target\manifest.json")) {

    Write-Host ""
    Write-Host "ERROR: manifest.json not found."

    Pop-Location

    exit 1
}

Write-Host "Manifest verified."
Write-Host ""

Pop-Location

# ------------------------------------------------------------
# Run Pre-Commit Hooks
# ------------------------------------------------------------

Write-Host "Running pre-commit hooks..."

uv run pre-commit run --all-files --show-diff-on-failure

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Pre-commit checks failed."

    exit 1
}

Write-Host ""
Write-Host "Pre-commit checks passed."

# ------------------------------------------------------------
# Success
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================="
Write-Host "        JOB 1 COMPLETED SUCCESSFULLY"
Write-Host "============================================================="
Write-Host ""