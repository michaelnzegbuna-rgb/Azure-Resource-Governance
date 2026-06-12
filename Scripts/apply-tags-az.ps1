<#
.SYNOPSIS
    Applies the mandatory tagging schema to existing resources in a Resource Group using Azure CLI (az).
.DESCRIPTION
    This script is designed for Windows environments where Azure CLI (az) is installed, but the
    Azure PowerShell module (Az) is not. It scans a resource group, checks each resource for 
    compliance, and uses 'az resource tag --operation Merge' to append missing mandatory tags.
.PARAMETER ResourceGroupName
    The name of the Resource Group containing resources to tag.
.PARAMETER Environment
    Default tag value for Environment (default: 'Dev').
.PARAMETER Owner
    Default tag value for Owner (default: 'admin@company.com').
.PARAMETER CostCenter
    Default tag value for CostCenter (default: 'CC-1001').
.PARAMETER Application
    Default tag value for Application (default: 'LegacyApp').
.PARAMETER DataClassification
    Default tag value for DataClassification (default: 'Internal').
.EXAMPLE
    .\apply-tags-az.ps1 -ResourceGroupName "rg-governance-demo" -Owner "dev-team@company.com"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [ValidateSet("Prod", "Stage", "Dev", "Test")]
    [string]$Environment = "Dev",

    [string]$Owner = "admin@company.com",

    [string]$CostCenter = "CC-1001",

    [string]$Application = "LegacyApp",

    [ValidateSet("Public", "Internal", "Confidential", "Restricted")]
    [string]$DataClassification = "Internal"
)

# Check if az CLI is available
$azCheck = Get-Command az -ErrorAction SilentlyContinue
if ($null -eq $azCheck) {
    Write-Error "Azure CLI (az) is not installed or not in the PATH. Please install it first."
    exit 1
}

# Verify login status
Write-Host "Verifying Azure CLI login status..." -ForegroundColor Cyan
$account = az account show --output json | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($null -eq $account) {
    Write-Error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "Fetching resources in Resource Group '$ResourceGroupName'..." -ForegroundColor Cyan
$resourcesRaw = az resource list --resource-group $ResourceGroupName --output json
if ($null -eq $resourcesRaw -or $resourcesRaw -eq "") {
    Write-Host "No resources found or Resource Group '$ResourceGroupName' does not exist." -ForegroundColor Yellow
    exit 0
}

$resources = $resourcesRaw | ConvertFrom-Json
if ($resources.Count -eq 0 -or $null -eq $resources) {
    Write-Host "No resources found in Resource Group '$ResourceGroupName'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($resources.Count) resource(s). Checking compliance and applying tags..." -ForegroundColor Cyan

$defaultTags = [ordered]@{
    "Environment"        = $Environment
    "Owner"              = $Owner
    "CostCenter"         = $CostCenter
    "Application"        = $Application
    "DataClassification" = $DataClassification
}

foreach ($resource in $resources) {
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    Write-Host "Resource: $($resource.name) [$($resource.type)]" -ForegroundColor White
    
    # Get current tags
    $currentTags = $resource.tags
    if ($null -eq $currentTags) {
        $currentTags = [PSCustomObject]@{}
    }
    
    # Check current tags count
    $tagKeys = $currentTags | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    Write-Host "Current Tags: $($tagKeys.Count) tag(s) found." -ForegroundColor Gray
    foreach ($key in $tagKeys) {
        Write-Host "  $key = $($currentTags.$key)" -ForegroundColor DarkGray
    }

    # Identify missing tags
    $tagsToApply = @()
    $needsUpdate = $false

    foreach ($tagKey in $defaultTags.Keys) {
        $hasTag = $false
        foreach ($k in $tagKeys) {
            if ($k -eq $tagKey) { $hasTag = $true; break }
        }

        if (-not $hasTag) {
            Write-Host "  [Missing Tag] Will add default '$tagKey' = '$($defaultTags[$tagKey])'" -ForegroundColor Yellow
            $tagsToApply += "$tagKey=$($defaultTags[$tagKey])"
            $needsUpdate = $true
        }
    }

    if ($needsUpdate) {
        Write-Host "  Updating tags for resource..." -ForegroundColor Cyan
        $tagString = $tagsToApply -join " "
        
        # Run az resource tag merge
        $null = az resource tag --ids $resource.id --tags $tagString --operation Merge
        
        # Verify success
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Tags updated successfully!" -ForegroundColor Green
        } else {
            Write-Warning "  Failed to update tags for '$($resource.name)'."
        }
    } else {
        Write-Host "  Resource is already compliant with mandatory tag presence rules." -ForegroundColor Green
    }
}

Write-Host "--------------------------------------------------" -ForegroundColor Gray
Write-Host "Tagging process completed." -ForegroundColor Green
