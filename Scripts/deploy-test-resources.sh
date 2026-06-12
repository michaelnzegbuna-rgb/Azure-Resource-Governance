#!/bin/bash

# SYNOPSIS: Tests Azure Policy tag enforcement using Azure CLI by deploying compliant and non-compliant Storage Accounts.
# USAGE: ./deploy-test-resources.sh -g <ResourceGroupName> [optional location]
# EXAMPLE: ./deploy-test-resources.sh -g rg-governance-demo -l eastus

set -e

# Default parameters
RG_NAME=""
LOCATION="eastus"

print_usage() {
    echo "Usage: ./deploy-test-resources.sh -g <ResourceGroupName> [-l <Location>]"
    echo "  -g : Resource Group name (Required)"
    echo "  -l : Azure Region (default: eastus)"
}

while getopts "g:l:h" opt; do
    case ${opt} in
        g ) RG_NAME=$OPTARG ;;
        l ) LOCATION=$OPTARG ;;
        h ) print_usage; exit 0 ;;
        \? ) print_usage; exit 1 ;;
    esac
done

if [ -z "$RG_NAME" ]; then
    echo "Error: Resource Group Name (-g) is required."
    print_usage
    exit 1
fi

# Ensure logged in
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Generate unique names
RAND=$((RANDOM % 90000 + 10000))
NON_COMPLIANT_NAME="noncompliantst$RAND"
COMPLIANT_NAME="compliantst$RAND"

echo "=================================================="
echo "TEST 1: Deploying Non-Compliant Storage Account (No Tags)"
echo "Expected result: Failure (Policy Deny)"
echo "Running: az storage account create --name $NON_COMPLIANT_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS"
echo "=================================================="

# Temporarily disable 'exit on error' so we can catch the failure
set +e
output=$(az storage account create \
  --name "$NON_COMPLIANT_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "CRITICAL: The non-compliant storage account was successfully created! This means the Azure Policy is not enforcing the Deny rule. Check if the policy assignment has taken effect (it can take up to 30 minutes)."
    exit 1
else
    echo -e "\n[SUCCESSFUL TEST] Deployment failed as expected!"
    echo "Error Details:"
    echo -e "\033[0;31m$output\033[0m"
    echo -e "\n>>> ACTION REQUIRED: Take a screenshot of the above error message showing the RequestDisallowedByPolicy block."
fi

echo -e "\n=================================================="
echo "TEST 2: Deploying Compliant Storage Account (With Required Tags)"
echo "Expected result: Success"
echo "Running: az storage account create --name $COMPLIANT_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS --tags Environment=Dev ..."
echo "=================================================="

# Create compliant storage account
az storage account create \
  --name "$COMPLIANT_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --tags "Environment=Dev" "Owner=admin@company.com" "CostCenter=CC-1001" "Application=GovernanceTest" "DataClassification=Internal"

echo -e "\n[SUCCESSFUL TEST] Storage account '$COMPLIANT_NAME' deployed successfully!"
az storage account show --name "$COMPLIANT_NAME" --resource-group "$RG_NAME" --query "{ID:id, Tags:tags}" -o json
