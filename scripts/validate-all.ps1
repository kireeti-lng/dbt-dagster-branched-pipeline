Write-Host ""
Write-Host "============================================================"
Write-Host "      LOCAL CI/CD VALIDATION"
Write-Host "============================================================"
Write-Host ""

$ErrorActionPreference = "Stop"

#----------------------------------------------------------
# Verify repository root
#----------------------------------------------------------

if (!(Test-Path "pyproject.toml")) {

    Write-Host "ERROR: Run this script from the repository root."

    exit 1
}

#----------------------------------------------------------
# Job 1
#----------------------------------------------------------

Write-Host ""
Write-Host "Starting Job 1 : Code Quality Gate"
Write-Host ""

& .\scripts\validate-job1.ps1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Job 1 FAILED"
    exit 1
}

Write-Host ""
Write-Host "Job 1 PASSED"
Write-Host ""

#----------------------------------------------------------
# Job 2
#----------------------------------------------------------

Write-Host ""
Write-Host "Starting Job 2 : dbt Validation"
Write-Host ""

& .\scripts\validate-job2.ps1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "Job 2 FAILED"
    exit 1
}

Write-Host ""
Write-Host "Job 2 PASSED"
Write-Host ""

Write-Host "============================================================"
Write-Host " ALL LOCAL VALIDATIONS PASSED"
Write-Host " SAFE TO PUSH TO GITHUB"
Write-Host "============================================================"