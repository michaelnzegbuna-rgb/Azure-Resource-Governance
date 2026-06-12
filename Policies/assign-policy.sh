#!/bin/bash

# SYNOPSIS: Deploys and assigns the custom Azure Policy definition to enforce resource tagging using Azure CLI.
# USAGE: ./assign-policy.sh -t <ScopeType> -n <ScopeName> -e <PolicyEffect>
# EXAMPLE: ./assign-policy.sh -t ResourceGroup -n rg-governance-demo -e Deny

set -e

# Default parameters
SCOPE_TYPE="ResourceGroup"
SCOPE_NAME=""
POLICY_EFFECT="Deny"

print_usage() {
    echo "Usage: ./assign-policy.sh -t [ResourceGroup|Subscription] -n [ScopeName/SubId] -e [Audit|Deny]"
    echo "  -t : Scope type (default: ResourceGroup)"
    echo "  -n : Scope Name (Resource Group name or Subscription ID)"
    echo "  -e : Policy Effect (default: Deny)"
}

while getopts "t:n:e:h" opt; do
    case ${opt} in
        t ) SCOPE_TYPE=$OPTARG ;;
        n ) SCOPE_NAME=$OPTARG ;;
        e ) POLICY_EFFECT=$OPTARG ;;
        h ) print_usage; exit 0 ;;
        \? ) print_usage; exit 1 ;;
    esac
done

if [ -z "$SCOPE_NAME" ]; then
    echo "Error: Scope Name (-n) is required."
    print_usage
    exit 1
fi

# Ensure logged in
echo "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

POLICY_RULES_FILE="require-tag-and-value-rules.json"
POLICY_PARAMS_FILE="require-tag-and-value-params.json"
if [ ! -f "$POLICY_RULES_FILE" ]; then
    # Check in subfolder relative to script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    POLICY_RULES_FILE="$SCRIPT_DIR/require-tag-and-value-rules.json"
    POLICY_PARAMS_FILE="$SCRIPT_DIR/require-tag-and-value-params.json"
    if [ ! -f "$POLICY_RULES_FILE" ]; then
        echo "Error: Policy files not found."
        exit 1
    fi
fi

# 1. Create or Update Policy Definition
DEFINITION_NAME="Enforce-Mandatory-Tags-And-Values"
echo "Creating/Updating custom policy definition '$DEFINITION_NAME'..."

az policy definition create \
    --name "$DEFINITION_NAME" \
    --display-name "Enforce Mandatory Tags and Allowed Values" \
    --description "Enforces presence of Environment, Owner, CostCenter, Application, and DataClassification tags, with specific allowed values for Environment and DataClassification." \
    --rules "$POLICY_RULES_FILE" \
    --params "$POLICY_PARAMS_FILE" \
    --mode Indexed \
    --metadata "category=Tags"

echo "Policy definition created successfully."

# 2. Determine Scope Resource ID
SCOPE_ID=""
if [ "$SCOPE_TYPE" == "ResourceGroup" ]; then
    echo "Validating Resource Group '$SCOPE_NAME'..."
    if ! az group show --name "$SCOPE_NAME" &> /dev/null; then
        echo "Error: Resource Group '$SCOPE_NAME' does not exist."
        exit 1
    fi
    SCOPE_ID=$(az group show --name "$SCOPE_NAME" --query id -o tsv)
    echo "Scope resolved to: $SCOPE_ID"
elif [ "$SCOPE_TYPE" == "Subscription" ]; then
    echo "Validating Subscription ID '$SCOPE_NAME'..."
    if ! az account set --subscription "$SCOPE_NAME" &> /dev/null; then
        echo "Error: Subscription ID '$SCOPE_NAME' not found or not accessible."
        exit 1
    fi
    SCOPE_ID="/subscriptions/$SCOPE_NAME"
    echo "Scope resolved to: $SCOPE_ID"
else
    echo "Error: Invalid Scope Type. Use 'ResourceGroup' or 'Subscription'."
    exit 1
fi

# 3. Create Policy Assignment
ASSIGNMENT_NAME="Assign-Enforce-Tags"
echo "Assigning policy to scope with effect '$POLICY_EFFECT'..."

az policy assignment create \
    --name "$ASSIGNMENT_NAME" \
    --display-name "Enforce Mandatory Tags and Allowed Values Assignment" \
    --policy "$DEFINITION_NAME" \
    --scope "$SCOPE_ID" \
    --params "{\"effect\": {\"value\": \"$POLICY_EFFECT\"}}"

echo "Policy assigned successfully!"
echo "Assignment Name: $ASSIGNMENT_NAME"
echo "Assignment Scope: $SCOPE_ID"
echo "Note: It may take 10-30 minutes for the policy assignment to take full effect in Azure."
