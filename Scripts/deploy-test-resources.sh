#!/bin/bash
# SYNOPSIS: Checks that Azure Policy tag enforcement works by attempting both a non-compliant and a compliant Storage Account deployment, using the Azure CLI.
# USAGE: ./deploy-test-resources.sh -g <ResourceGroupName> [optional location]
# EXAMPLE: ./deploy-test-resources.sh -g rg-governance-demo -l eastus
set -e

# Default parameters
RG_NAME=""
LOCATION="eastus"

print_usage() {
    echo "Usage: ./deploy-test-resources.sh -g <ResourceGroupName> [-l <Location>]"
    echo "  -g : Resource Group name (required)"
    echo "  -l : Azure region (defaults to eastus)"
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
    echo "Error: a Resource Group name (-g) must be provided."
    print_usage
    exit 1
fi

# Confirm an active Azure session exists
if ! az account show &> /dev/null; then
    echo "Error: no active Azure session found. Run 'az login' before retrying."
    exit 1
fi

# Build unique names for the test
RAND=$((RANDOM % 90000 + 10000))
NON_COMPLIANT_NAME="noncompliantst$RAND"
COMPLIANT_NAME="compliantst$RAND"

echo "=================================================="
echo "TEST 1: Deploying a Non-Compliant Storage Account (No Tags)"
echo "Expected outcome: this should fail (Policy Deny)"
echo "Running: az storage account create --name $NON_COMPLIANT_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS"
echo "=================================================="

# Temporarily turn off 'exit on error' so the failure can be caught and inspected
set +e
output=$(az storage account create \
  --name "$NON_COMPLIANT_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "CRITICAL: the non-compliant storage account went through! That means the Azure Policy isn't enforcing the Deny rule as expected. Check whether the policy assignment has fully propagated (this can take up to 30 minutes)."
    exit 1
else
    echo -e "\n[Test passed] Deployment was blocked, as expected!"
    echo "Error details:"
    echo -e "\033[0;31m$output\033[0m"
    echo -e "\n>>> NEXT STEP: Capture a screenshot of the error above showing the RequestDisallowedByPolicy block."
fi

echo -e "\n=================================================="
echo "TEST 2: Deploying a Compliant Storage Account (With Required Tags)"
echo "Expected outcome: this should succeed"
echo "Running: az storage account create --name $COMPLIANT_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS --tags Environment=Dev ..."
echo "=================================================="

# Create the compliant storage account
az storage account create \
  --name "$COMPLIANT_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --tags "Environment=Dev" "Owner=admin@company.com" "CostCenter=CC-1001" "Application=GovernanceTest" "DataClassification=Internal"

echo -e "\n[Test passed] Storage account '$COMPLIANT_NAME' deployed without issue!"
az storage account show --name "$COMPLIANT_NAME" --resource-group "$RG_NAME" --query "{ID:id, Tags:tags}" -o json
