# =====================================================================
# validate-all.ps1
#
# Runs the complete local CI/CD validation pipeline.
#
# Mirrors GitHub Actions:
#
#   Job 1
#       ↓
#   Job 2
#
# Usage:
#
#   .\scripts\validate-all.ps1
#
# =====================================================================

$ErrorActionPreference = "Stop"

Clear-Host

$PipelineStart = Get-Date

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          LOCAL CI/CD VALIDATION PIPELINE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------
# Verify Repository Root
# ---------------------------------------------------------------------

if (!(Test-Path "pyproject.toml")) {

    Write-Host ""
    Write-Host "ERROR: Run this script from the repository root." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Verify Required Scripts
# ---------------------------------------------------------------------

$requiredScripts = @(
    "scripts\setup-env.ps1",
    "scripts\validate-job1.ps1",
    "scripts\validate-job2.ps1",
    "scripts\validate_dbt.py"
)

foreach ($script in $requiredScripts) {

    if (!(Test-Path $script)) {

        Write-Host ""
        Write-Host "Missing required file:" -ForegroundColor Red
        Write-Host "  $script"
        exit 1
    }
}

# ---------------------------------------------------------------------
# Load Environment
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Loading Local Environment..." -ForegroundColor Yellow

try {

    . .\scripts\setup-env.ps1

}
catch {

    Write-Host ""
    Write-Host "Environment setup failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# Execute Job 1
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Starting Job 1..." -ForegroundColor Yellow

$Job1Start = Get-Date

& .\scripts\validate-job1.ps1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "JOB 1 FAILED" -ForegroundColor Red
    exit 1
}

$Job1Time = (Get-Date) - $Job1Start

Write-Host ""
Write-Host "JOB 1 PASSED" -ForegroundColor Green
Write-Host ("Duration : {0:n2} sec" -f $Job1Time.TotalSeconds)

# ---------------------------------------------------------------------
# Execute Job 2
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Starting Job 2..." -ForegroundColor Yellow

$Job2Start = Get-Date

& .\scripts\validate-job2.ps1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "JOB 2 FAILED" -ForegroundColor Red
    exit 1
}

$Job2Time = (Get-Date) - $Job2Start

Write-Host ""
Write-Host "JOB 2 PASSED" -ForegroundColor Green
Write-Host ("Duration : {0:n2} sec" -f $Job2Time.TotalSeconds)

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------

$PipelineTime = (Get-Date) - $PipelineStart

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "             LOCAL VALIDATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Pipeline Summary" -ForegroundColor Cyan
Write-Host "----------------"

Write-Host ""
Write-Host "[PASS] Environment Setup"
Write-Host "[PASS] Job 1 - Code Quality Gate"
Write-Host "[PASS] Job 2 - dbt Validation"

Write-Host ""
Write-Host ("Job 1 Duration : {0:n2} sec" -f $Job1Time.TotalSeconds)
Write-Host ("Job 2 Duration : {0:n2} sec" -f $Job2Time.TotalSeconds)
Write-Host ("Total Duration : {0:n2} sec" -f $PipelineTime.TotalSeconds)

Write-Host ""
Write-Host "Repository is ready to push." -ForegroundColor Green
Write-Host "GitHub Actions should produce identical results." -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green