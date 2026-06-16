#!/bin/bash
# SYNOPSIS: Registers and assigns the custom Azure Policy definition that enforces resource tagging, using the Azure CLI.
# USAGE: ./assign-policy.sh -t <ScopeType> -n <ScopeName> -e <PolicyEffect>
# EXAMPLE: ./assign-policy.sh -t ResourceGroup -n rg-governance-demo -e Deny
set -e

# Default parameters
SCOPE_TYPE="ResourceGroup"
SCOPE_NAME=""
POLICY_EFFECT="Deny"

print_usage() {
    echo "Usage: ./assign-policy.sh -t [ResourceGroup|Subscription] -n [ScopeName/SubId] -e [Audit|Deny]"
    echo "  -t : Scope type (defaults to ResourceGroup)"
    echo "  -n : Scope name (Resource Group name or Subscription ID)"
    echo "  -e : Policy effect (defaults to Deny)"
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
    echo "Error: a scope name (-n) must be provided."
    print_usage
    exit 1
fi

# Confirm an active Azure session exists
echo "Checking current Azure CLI session..."
if ! az account show &> /dev/null; then
    echo "Error: no active Azure session found. Run 'az login' before retrying."
    exit 1
fi

POLICY_RULES_FILE="require-tag-and-value-rules.json"
POLICY_PARAMS_FILE="require-tag-and-value-params.json"
if [ ! -f "$POLICY_RULES_FILE" ]; then
    # Fall back to looking relative to the script's own directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    POLICY_RULES_FILE="$SCRIPT_DIR/require-tag-and-value-rules.json"
    POLICY_PARAMS_FILE="$SCRIPT_DIR/require-tag-and-value-params.json"
    if [ ! -f "$POLICY_RULES_FILE" ]; then
        echo "Error: couldn't locate the policy definition files."
        exit 1
    fi
fi

# 1. Register the policy definition
DEFINITION_NAME="Enforce-Mandatory-Tags-And-Values"
echo "Registering custom policy definition '$DEFINITION_NAME'..."
az policy definition create \
    --name "$DEFINITION_NAME" \
    --display-name "Enforce Mandatory Tags and Allowed Values" \
    --description "Enforces presence of Environment, Owner, CostCenter, Application, and DataClassification tags, with specific allowed values for Environment and DataClassification." \
    --rules "$POLICY_RULES_FILE" \
    --params "$POLICY_PARAMS_FILE" \
    --mode Indexed \
    --metadata "category=Tags"
echo "Policy definition is registered and up to date."

# 2. Resolve the target scope's resource ID
SCOPE_ID=""
if [ "$SCOPE_TYPE" == "ResourceGroup" ]; then
    echo "Confirming Resource Group '$SCOPE_NAME' exists..."
    if ! az group show --name "$SCOPE_NAME" &> /dev/null; then
        echo "Error: Resource Group '$SCOPE_NAME' could not be found."
        exit 1
    fi
    SCOPE_ID=$(az group show --name "$SCOPE_NAME" --query id -o tsv)
    echo "Target scope resolved to: $SCOPE_ID"
elif [ "$SCOPE_TYPE" == "Subscription" ]; then
    echo "Confirming access to Subscription '$SCOPE_NAME'..."
    if ! az account set --subscription "$SCOPE_NAME" &> /dev/null; then
        echo "Error: Subscription '$SCOPE_NAME' was not found or you don't have access to it."
        exit 1
    fi
    SCOPE_ID="/subscriptions/$SCOPE_NAME"
    echo "Target scope resolved to: $SCOPE_ID"
else
    echo "Error: invalid scope type — use 'ResourceGroup' or 'Subscription'."
    exit 1
fi

# 3. Create the policy assignment
ASSIGNMENT_NAME="Assign-Enforce-Tags"
echo "Applying policy to the target scope with effect '$POLICY_EFFECT'..."
az policy assignment create \
    --name "$ASSIGNMENT_NAME" \
    --display-name "Enforce Mandatory Tags and Allowed Values Assignment" \
    --policy "$DEFINITION_NAME" \
    --scope "$SCOPE_ID" \
    --params "{\"effect\": {\"value\": \"$POLICY_EFFECT\"}}"

echo "Policy assignment complete!"
echo "Assignment Name: $ASSIGNMENT_NAME"
echo "Assignment Scope: $SCOPE_ID"
echo "Note: Azure may take 10-30 minutes to fully apply this assignment."
