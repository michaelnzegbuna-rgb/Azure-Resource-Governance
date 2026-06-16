<#
.SYNOPSIS
    Registers and assigns the custom Azure Policy definition that enforces resource tagging.
.DESCRIPTION
    This script registers the 'Enforce Mandatory Tags and Allowed Values' custom policy with Azure
    and creates an assignment at either the resource group or subscription level, depending on
    the scope you specify.
.PARAMETER ScopeType
    Choose either 'ResourceGroup' (the default) or 'Subscription'.
.PARAMETER ScopeName
    The Resource Group name or Subscription ID you want the policy applied to.
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

# Confirm an active Azure session exists
$context = Get-AzContext
if ($null -eq $context) {
    Write-Error "No active Azure session detected. Run 'Connect-AzAccount' before retrying."
    exit 1
}

# 1. Register the policy definition
Write-Host "Registering custom policy definition from require-tag-and-value.json..." -ForegroundColor Cyan
$policyFile = Join-Path $PSScriptRoot "require-tag-and-value.json"
if (-not (Test-Path $policyFile)) {
    Write-Error "Could not find policy file at: $policyFile"
    exit 1
}
$definitionName = "Enforce-Mandatory-Tags-And-Values"
$definition = New-AzPolicyDefinition -Name $definitionName -DisplayName "Enforce Mandatory Tags and Allowed Values" -Policy $policyFile -Metadata @{ category = "Tags" } -Force
Write-Host "Policy definition '$definitionName' is registered and up to date." -ForegroundColor Green

# 2. Resolve the target scope's resource ID
$scopeId = ""
if ($ScopeType -eq "ResourceGroup") {
    $rg = Get-AzResourceGroup -Name $ScopeName -ErrorAction SilentlyContinue
    if ($null -eq $rg) {
        Write-Error "Resource Group '$ScopeName' could not be found. Double-check the name or create it first."
        exit 1
    }
    $scopeId = $rg.ResourceId
    Write-Host "Target scope resolved to Resource Group: $scopeId" -ForegroundColor Cyan
} else {
    $sub = Get-AzSubscription -SubscriptionId $ScopeName -ErrorAction SilentlyContinue
    if ($null -eq $sub) {
        Write-Error "Subscription '$ScopeName' was not found or you don't have access to it."
        exit 1
    }
    $scopeId = "/subscriptions/$($sub.Id)"
    Write-Host "Target scope resolved to Subscription: $scopeId" -ForegroundColor Cyan
}

# 3. Create the policy assignment
Write-Host "Applying policy to the target scope with effect '$PolicyEffect'..." -ForegroundColor Cyan
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

Write-Host "Policy assignment complete!" -ForegroundColor Green
Write-Host "Assignment Name: $($assignment.Name)" -ForegroundColor Yellow
Write-Host "Assignment Scope: $($assignment.Scope)" -ForegroundColor Yellow
Write-Host "Note: Azure may take 10-30 minutes to fully apply this assignment." -ForegroundColor Green
