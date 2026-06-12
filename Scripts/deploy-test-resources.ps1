<#
.SYNOPSIS
    Tests Azure Policy tag enforcement by deploying compliant and non-compliant Storage Accounts.
.DESCRIPTION
    1. Attempts to deploy a Storage Account without tags. This should trigger the Deny policy
       and output a Policy Violation error (perfect for the required screenshot).
    2. Attempts to deploy a Storage Account with all required tags. This should succeed.
.PARAMETER ResourceGroupName
    The Resource Group where the test will take place.
.PARAMETER Location
    The Azure region for the storage accounts (default: 'eastus').
.EXAMPLE
    .\deploy-test-resources.ps1 -ResourceGroupName "rg-governance-demo" -Location "eastus"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$Location = "eastus"
)

# Ensure logged in
$context = Get-AzContext
if ($null -eq $context) {
    Write-Error "Not logged in to Azure. Please run 'Connect-AzAccount' first."
    exit 1
}

# Generate unique names
$rand = Get-Random -Minimum 10000 -Maximum 99999
$nonCompliantName = "noncompliantst$rand"
$compliantName = "compliantst$rand"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "TEST 1: Deploying Non-Compliant Storage Account (No Tags)" -ForegroundColor Cyan
Write-Host "Expected result: Failure (Policy Deny)" -ForegroundColor Yellow
Write-Host "Running: New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $nonCompliantName -Location $Location -SkuName Standard_LRS" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan

try {
    # Attempt deployment
    $storage = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                                     -Name $nonCompliantName `
                                     -Location $Location `
                                     -SkuName Standard_LRS `
                                     -ErrorAction Stop
    Write-Error "CRITICAL: The non-compliant storage account was successfully created! This means the Azure Policy is not enforcing the Deny rule. Check if the policy assignment has taken effect (it can take up to 30 minutes)."
}
catch {
    Write-Host "`n[SUCCESSFUL TEST] Deployment failed as expected!" -ForegroundColor Green
    Write-Host "Error Details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`n>>> ACTION REQUIRED: Take a screenshot of the above error message showing the Policy Violation/Deny block." -ForegroundColor Cyan
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "TEST 2: Deploying Compliant Storage Account (With Required Tags)" -ForegroundColor Cyan
Write-Host "Expected result: Success" -ForegroundColor Yellow
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
    
    Write-Host "`n[SUCCESSFUL TEST] Storage account '$compliantName' deployed successfully!" -ForegroundColor Green
    Write-Host "Resource ID: $($storage.Id)" -ForegroundColor Gray
    Write-Host "Tags Applied:" -ForegroundColor Gray
    foreach ($key in $storage.Tags.Keys) {
        Write-Host "  $key = $($storage.Tags[$key])" -ForegroundColor DarkGray
    }
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Host "Note: If this failed with a policy error, make sure the tag values exactly match the allowed values in the policy definition." -ForegroundColor Yellow
}
