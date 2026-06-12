<#
.SYNOPSIS
    Deploys and assigns the custom Azure Policy definition to enforce resource tagging.
.DESCRIPTION
    This script registers the 'Enforce Mandatory Tags and Allowed Values' custom policy in Azure
    and creates a policy assignment at the specified resource group or subscription scope.
.PARAMETER ScopeType
    Specify either 'ResourceGroup' (default) or 'Subscription'.
.PARAMETER ScopeName
    The name of the Resource Group or Subscription ID to target.
.EXAMPLE
    .\assign-policy.ps1 -ScopeType "ResourceGroup" -ScopeName "rg-governance-demo"
#>

[CmdletBinding()]
param (
    [ValidateSet("ResourceGroup", "Subscription")]
    [string]$ScopeType = "ResourceGroup",

    [Parameter(Mandatory = $true)]
    [string]$ScopeName,

    [ValidateSet("Audit", "Deny", "Disabled")]
    [string]$PolicyEffect = "Deny"
)

# Ensure logged in
$context = Get-AzContext
if ($null -eq $context) {
    Write-Error "Not logged in to Azure. Please run 'Connect-AzAccount' first."
    exit 1
}

# 1. Create or Update Policy Definition
Write-Host "Creating custom policy definition from require-tag-and-value.json..." -ForegroundColor Cyan
$policyFile = Join-Path $PSScriptRoot "require-tag-and-value.json"
if (-not (Test-Path $policyFile)) {
    Write-Error "Policy file not found: $policyFile"
    exit 1
}

$definitionName = "Enforce-Mandatory-Tags-And-Values"
$definition = New-AzPolicyDefinition -Name $definitionName -DisplayName "Enforce Mandatory Tags and Allowed Values" -Policy $policyFile -Metadata @{ category = "Tags" } -Force

Write-Host "Policy definition '$definitionName' successfully created/updated." -ForegroundColor Green

# 2. Determine Scope Resource ID
$scopeId = ""
if ($ScopeType -eq "ResourceGroup") {
    $rg = Get-AzResourceGroup -Name $ScopeName -ErrorAction SilentlyContinue
    if ($null -eq $rg) {
        Write-Error "Resource Group '$ScopeName' not found. Please create it or verify the name."
        exit 1
    }
    $scopeId = $rg.ResourceId
    Write-Host "Scope resolved to Resource Group: $scopeId" -ForegroundColor Cyan
} else {
    $sub = Get-AzSubscription -SubscriptionId $ScopeName -ErrorAction SilentlyContinue
    if ($null -eq $sub) {
        Write-Error "Subscription ID '$ScopeName' not found or not accessible."
        exit 1
    }
    $scopeId = "/subscriptions/$($sub.Id)"
    Write-Host "Scope resolved to Subscription: $scopeId" -ForegroundColor Cyan
}

# 3. Create Policy Assignment
Write-Host "Assigning policy to scope with effect '$PolicyEffect'..." -ForegroundColor Cyan
$assignmentName = "Assign-Enforce-Tags"

$params = @{
    effect = $PolicyEffect
}

$assignment = New-AzPolicyAssignment -Name $assignmentName `
                                     -DisplayName "Enforce Mandatory Tags and Allowed Values Assignment" `
                                     -PolicyDefinition $definition `
                                     -Scope $scopeId `
                                     -PolicyParameterObject $params `
                                     -Force

Write-Host "Policy successfully assigned!" -ForegroundColor Green
Write-Host "Assignment Name: $($assignment.Name)" -ForegroundColor Yellow
Write-Host "Assignment Scope: $($assignment.Scope)" -ForegroundColor Yellow
Write-Host "Note: It may take 10-30 minutes for the policy assignment to take full effect in Azure." -ForegroundColor Green
