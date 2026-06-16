<#
.SYNOPSIS
    Checks that Azure Policy tag enforcement works by attempting both a non-compliant and a compliant Storage Account deployment.
.DESCRIPTION
    1. First tries to deploy a Storage Account with no tags. This should be blocked by the
       Deny policy and surface a Policy Violation error — the exact output you'd want to capture
       in a screenshot.
    2. Then tries to deploy a Storage Account carrying all the required tags. This one should
       go through without issue.
.PARAMETER ResourceGroupName
    Resource Group where the test deployments will happen.
.PARAMETER Location
    Azure region to deploy the storage accounts into (defaults to 'eastus').
.EXAMPLE
    .\deploy-test-resources.ps1 -ResourceGroupName "rg-governance-demo" -Location "eastus"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$Location = "eastus"
)

# Confirm an active Azure session exists
$context = Get-AzContext
if ($null -eq $context) {
    Write-Error "No active Azure session detected. Run 'Connect-AzAccount' before retrying."
    exit 1
}

# Build unique names for the test
$rand = Get-Random -Minimum 10000 -Maximum 99999
$nonCompliantName = "noncompliantst$rand"
$compliantName = "compliantst$rand"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "TEST 1: Deploying a Non-Compliant Storage Account (No Tags)" -ForegroundColor Cyan
Write-Host "Expected outcome: this should fail (Policy Deny)" -ForegroundColor Yellow
Write-Host "Running: New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $nonCompliantName -Location $Location -SkuName Standard_LRS" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan

try {
    # Attempt the deployment
    $storage = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                                     -Name $nonCompliantName `
                                     -Location $Location `
                                     -SkuName Standard_LRS `
                                     -ErrorAction Stop
    Write-Error "CRITICAL: the non-compliant storage account went through! That means the Azure Policy isn't enforcing the Deny rule as expected. Check whether the policy assignment has fully propagated (this can take up to 30 minutes)."
}
catch {
    Write-Host "`n[Test passed] Deployment was blocked, as expected!" -ForegroundColor Green
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`n>>> NEXT STEP: Capture a screenshot of the error above showing the Policy Violation/Deny block." -ForegroundColor Cyan
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "TEST 2: Deploying a Compliant Storage Account (With Required Tags)" -ForegroundColor Cyan
Write-Host "Expected outcome: this should succeed" -ForegroundColor Yellow
Write-Host "Running: New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $compliantName -Location $Location -SkuName Standard_LRS -Tag <GovTags>" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan

$compliantTags = @{
    Environment        = "Dev"
    Owner              = "admin@company.com"
    CostCenter         = "CC-1001"
    Application        = "GovernanceTest"
    DataClassification = "Internal"
}

try {
    $storage = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                                     -Name $compliantName `
                                     -Location $Location `
                                     -SkuName Standard_LRS `
                                     -Tag $compliantTags `
                                     -ErrorAction Stop
    
    Write-Host "`n[Test passed] Storage account '$compliantName' deployed without issue!" -ForegroundColor Green
    Write-Host "Resource ID: $($storage.Id)" -ForegroundColor Gray
    Write-Host "Tags applied:" -ForegroundColor Gray
    foreach ($key in $storage.Tags.Keys) {
        Write-Host "  $key = $($storage.Tags[$key])" -ForegroundColor DarkGray
    }
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Host "Note: if this failed because of a policy error, double-check that the tag values exactly match what the policy definition allows." -ForegroundColor Yellow
}
