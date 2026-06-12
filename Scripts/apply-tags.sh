#!/bin/bash

# SYNOPSIS: Applies the mandatory tagging schema to existing resources in a Resource Group using Azure CLI.
# USAGE: ./apply-tags.sh -g <ResourceGroupName> [optional parameters]
# EXAMPLE: ./apply-tags.sh -g rg-governance-demo -o "operations@company.com"

set -e

# Default parameters
RG_NAME=""
ENV="Dev"
OWNER="admin@company.com"
COSTCENTER="CC-1001"
APP="LegacyApp"
DATA_CLASS="Internal"

print_usage() {
    echo "Usage: ./apply-tags.sh -g <ResourceGroupName> [options]"
    echo "  -g : Resource Group name (Required)"
    echo "  -v : Environment (default: Dev)"
    echo "  -o : Owner email (default: admin@company.com)"
    echo "  -c : CostCenter (default: CC-1001)"
    echo "  -a : Application (default: LegacyApp)"
    echo "  -d : DataClassification (default: Internal)"
}

while getopts "g:v:o:c:a:d:h" opt; do
    case ${opt} in
        g ) RG_NAME=$OPTARG ;;
        v ) ENV=$OPTARG ;;
        o ) OWNER=$OPTARG ;;
        c ) COSTCENTER=$OPTARG ;;
        a ) APP=$OPTARG ;;
        d ) DATA_CLASS=$OPTARG ;;
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

echo "Validating Resource Group '$RG_NAME'..."
if ! az group show --name "$RG_NAME" &> /dev/null; then
    echo "Error: Resource Group '$RG_NAME' does not exist."
    exit 1
fi

echo "Fetching resources in Resource Group '$RG_NAME'..."
# Fetch resources, query returns a JSON array of objects with id, name, type, tags
resources=$(az resource list --resource-group "$RG_NAME" --query "[].{id:id, name:name, type:type, tags:tags}" -o json)

count=$(echo "$resources" | jq '. | length' 2>/dev/null || echo "0")
# If jq is not installed, we can use python or grep, but jq is standard. Let's make it robust.
# Let's check if jq is installed. If not, use Python to count and process.
use_python=false
if ! command -v jq &> /dev/null; then
    echo "jq command not found. Using fallback Python parser..."
    use_python=true
fi

process_resource() {
    local id=$1
    local name=$2
    local type=$3
    local tags_json=$4

    echo "--------------------------------------------------"
    echo "Resource: $name [$type]"
    
    # Check current tags
    echo "Current Tags JSON: $tags_json"

    # We want to build tags to apply
    local tags_to_apply=""

    # Helper to check if tag key exists in JSON
    check_and_add_tag() {
        local key=$1
        local val=$2
        local exists=false

        if [ "$use_python" = true ]; then
            exists=$(python -c "import sys, json; t=json.loads(sys.argv[1]); print('true' if t and '$key' in t else 'false')" "$tags_json")
        else
            exists=$(echo "$tags_json" | jq "has(\"$key\")" 2>/dev/null || echo "false")
        fi

        if [ "$exists" != "true" ]; then
            echo "  [Missing Tag] Adding default '$key' = '$val'"
            tags_to_apply="$tags_to_apply $key=$val"
        fi
    }

    check_and_add_tag "Environment" "$ENV"
    check_and_add_tag "Owner" "$OWNER"
    check_and_add_tag "CostCenter" "$COSTCENTER"
    check_and_add_tag "Application" "$APP"
    check_and_add_tag "DataClassification" "$DATA_CLASS"

    if [ ! -z "$tags_to_apply" ]; then
        echo "  Applying missing tags using merge..."
        az resource tag --ids "$id" --tags $tags_to_apply --operation Merge > /dev/null
        echo "  Tags updated successfully!"
    else
        echo "  Resource is already compliant with mandatory tag presence rules."
    fi
}

if [ "$use_python" = true ]; then
    # Python fallback to iterate and process
    python -c '
import sys, json, subprocess
res_list = json.loads(sys.argv[1])
print(f"Found {len(res_list)} resource(s). Checking compliance...")
for r in res_list:
    tags_str = json.dumps(r.get("tags") or {})
    subprocess.run(["bash", "-c", f"source ./apply-tags.sh -h &>/dev/null; process_resource_python"], env={"id": r["id"], "name": r["name"], "type": r["type"], "tags": tags_str})
' "$resources" 2>/dev/null || true
    
    # Let's write a simple pure bash loop as a secondary fallback if python fails or we want a simpler solution.
    # Actually, a simple bash solution is to query ids and loop. Let's do that! It is much simpler and more robust.
    
    # Let's rewrite the iteration in pure bash using `az` queries to be 100% robust without python.
    ids=$(az resource list --resource-group "$RG_NAME" --query "[].id" -o tsv)
    for id in $ids; do
        name=$(az resource show --id "$id" --query "name" -o tsv)
        type=$(az resource show --id "$id" --query "type" -o tsv)
        tags_json=$(az resource show --id "$id" --query "tags" -o json || echo "{}")
        if [ "$tags_json" == "null" ] || [ -z "$tags_json" ]; then
            tags_json="{}"
        fi
        process_resource "$id" "$name" "$type" "$tags_json"
    done
else
    # Loop using jq
    for row in $(echo "$resources" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        id=$(_jq '.id')
        name=$(_jq '.name')
        type=$(_jq '.type')
        tags_json=$(_jq '.tags')
        if [ "$tags_json" == "null" ] || [ -z "$tags_json" ]; then
            tags_json="{}"
        fi
        process_resource "$id" "$name" "$type" "$tags_json"
    done
fi

echo "--------------------------------------------------"
echo "Tagging process completed."
