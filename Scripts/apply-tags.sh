#!/bin/bash

# SYNOPSIS: Walks through resources in a Resource Group and applies the required tagging schema, via the Azure CLI.
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
    echo "  -g : Resource Group name (mandatory)"
    echo "  -v : Environment tag value (Dev by default)"
    echo "  -o : Owner tag value (admin@company.com by default)"
    echo "  -c : CostCenter tag value (CC-1001 by default)"
    echo "  -a : Application tag value (LegacyApp by default)"
    echo "  -d : DataClassification tag value (Internal by default)"
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
    echo "Error: you must supply a Resource Group name via -g."
    print_usage
    exit 1
fi

# Make sure we're authenticated against Azure
if ! az account show &> /dev/null; then
    echo "Error: not currently signed in to Azure. Run 'az login' first."
    exit 1
fi

echo "Checking that Resource Group '$RG_NAME' actually exists..."
if ! az group show --name "$RG_NAME" &> /dev/null; then
    echo "Error: no Resource Group named '$RG_NAME' was found."
    exit 1
fi

echo "Retrieving the resource inventory for '$RG_NAME'..."
# Returns a JSON array of objects, each with id, name, type, tags
resources=$(az resource list --resource-group "$RG_NAME" --query "[].{id:id, name:name, type:type, tags:tags}" -o json)

count=$(echo "$resources" | jq '. | length' 2>/dev/null || echo "0")
# Prefer jq for parsing, but degrade gracefully to Python if jq isn't installed
use_python=false
if ! command -v jq &> /dev/null; then
    echo "jq not detected on this system — falling back to the Python-based path..."
    use_python=true
fi

process_resource() {
    local id=$1
    local name=$2
    local type=$3
    local tags_json=$4

    echo "--------------------------------------------------"
    echo "Resource: $name [$type]"
    
    # Display the tags already attached to this resource
    echo "Tags currently on record: $tags_json"

    # Holds any tags that still need adding
    local tags_to_apply=""

    # Tests for the presence of a single tag key
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
            echo "  [Not set] Will add '$key' = '$val'"
            tags_to_apply="$tags_to_apply $key=$val"
        fi
    }

    check_and_add_tag "Environment" "$ENV"
    check_and_add_tag "Owner" "$OWNER"
    check_and_add_tag "CostCenter" "$COSTCENTER"
    check_and_add_tag "Application" "$APP"
    check_and_add_tag "DataClassification" "$DATA_CLASS"

    if [ ! -z "$tags_to_apply" ]; then
        echo "  Pushing the missing tags through a merge operation..."
        az resource tag --ids "$id" --tags $tags_to_apply --operation Merge > /dev/null
        echo "  Done — tags are now in place."
    else
        echo "  Nothing to do here — all mandatory tags are already set."
    fi
}

if [ "$use_python" = true ]; then
    # First attempt: drive the iteration through Python
    python -c '
import sys, json, subprocess
res_list = json.loads(sys.argv[1])
print(f"Found {len(res_list)} resource(s). Working through compliance checks...")
for r in res_list:
    tags_str = json.dumps(r.get("tags") or {})
    subprocess.run(["bash", "-c", f"source ./apply-tags.sh -h &>/dev/null; process_resource_python"], env={"id": r["id"], "name": r["name"], "type": r["type"], "tags": tags_str})
' "$resources" 2>/dev/null || true
    
    # Fallback: a self-contained bash loop that doesn't depend on Python at all
    
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
    # Standard path: parse with jq
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
echo "All resources have been processed."
