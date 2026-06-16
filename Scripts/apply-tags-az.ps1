<#
.SYNOPSIS
    Applies the mandatory tagging schema across existing resources in a Resource Group, using the Azure CLI (az).
.DESCRIPTION
    Built for Windows environments that have Azure CLI installed but not the Azure PowerShell (Az)
    module, this script walks through a resource group, checks each resource for missing mandatory
    tags, and uses 'az resource tag --operation Merge' to fill in whatever is absent.
.PARAMETER ResourceGroupName
    Resource Group whose resources need tagging.
.PARAMETER Environment
    Fallback value for the Environment tag (defaults to 'Dev').
.PARAMETER Owner
    Fallback value for the Owner tag (defaults to 'admin@company.com').
.PARAMETER CostCenter
    Fallback value for the CostCenter tag (defaults to 'CC-1001').
.PARAMETER Application
    Fallback value for the Application tag (defaults to 'LegacyApp').
.PARAMETER DataClassification
    Fallback value for the DataClassification tag (defaults to 'Internal').
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

# Confirm Azure CLI is installed
$azCheck = Get-Command az -ErrorAction SilentlyContinue
if ($null -eq $azCheck) {
    Write-Error "Azure CLI (az) was not found. Install it and make sure it's available on PATH."
    exit 1
}

# Confirm an active Azure session exists
Write-Host "Checking current Azure CLI session..." -ForegroundColor Cyan
$account = az account show --output json | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($null -eq $account) {
    Write-Error "No active Azure session detected. Run 'az login' before retrying."
    exit 1
}

Write-Host "Pulling resource list for Resource Group '$ResourceGroupName'..." -ForegroundColor Cyan
$resourcesRaw = az resource list --resource-group $ResourceGroupName --output json
if ($null -eq $resourcesRaw -or $resourcesRaw -eq "") {
    Write-Host "Nothing came back — either the Resource Group '$ResourceGroupName' doesn't exist or it's empty." -ForegroundColor Yellow
    exit 0
}

$resources = $resourcesRaw | ConvertFrom-Json
if ($resources.Count -eq 0 -or $null -eq $resources) {
    Write-Host "Resource Group '$ResourceGroupName' has no resources to tag." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($resources.Count) resource(s). Reviewing compliance and applying tags where needed..." -ForegroundColor Cyan

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
    
    # Pull existing tags
    $currentTags = $resource.tags
    if ($null -eq $currentTags) {
        $currentTags = [PSCustomObject]@{}
    }
    
    # Show what's already there
    $tagKeys = $currentTags | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    Write-Host "Existing tags: $($tagKeys.Count) found." -ForegroundColor Gray
    foreach ($key in $tagKeys) {
        Write-Host "  $key = $($currentTags.$key)" -ForegroundColor DarkGray
    }

    # Work out which mandatory tags are absent
    $tagsToApply = @()
    $needsUpdate = $false

    foreach ($tagKey in $defaultTags.Keys) {
        $hasTag = $false
        foreach ($k in $tagKeys) {
            if ($k -eq $tagKey) { $hasTag = $true; break }
        }

        if (-not $hasTag) {
            Write-Host "  [Tag absent] Applying default '$tagKey' = '$($defaultTags[$tagKey])'" -ForegroundColor Yellow
            $tagsToApply += "$tagKey=$($defaultTags[$tagKey])"
            $needsUpdate = $true
        }
    }

    if ($needsUpdate) {
        Write-Host "  Merging missing tags onto this resource..." -ForegroundColor Cyan
        $tagString = $tagsToApply -join " "
        
        # Run az resource tag merge
        $null = az resource tag --ids $resource.id --tags $tagString --operation Merge
        
        # Confirm the merge worked
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Tags applied!" -ForegroundColor Green
        } else {
            Write-Warning "  Could not apply tags to '$($resource.name)'."
        }
    } else {
        Write-Host "  This resource already has every mandatory tag." -ForegroundColor Green
    }
}

Write-Host "--------------------------------------------------" -ForegroundColor Gray
Write-Host "Tagging pass finished." -ForegroundColor Green
