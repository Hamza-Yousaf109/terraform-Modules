#!/bin/bash

set -e

# Usage: ./terraform_to_ansible.sh <input-json> <output-file>

if [ $# -lt 2 ]; then
    echo "Usage: terraform_to_ansible.sh <input-json> <output-file>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

# Debug: Show raw output structure
echo "📍 Processing Terraform output..."

# Try to extract instances - handle both terraform output formats
INSTANCES=$(jq -r '.instances_with_ssh.value.instances[]? | select(. != null) | "\(.name) ansible_host=\(.ansible_host) ansible_user=\(.ansible_user)"' "$INPUT_FILE" 2>/dev/null || echo "")

# Generate inventory file
{
    echo "# Auto-generated inventory"
    echo ""
    echo "[jenkins_servers]"
    
    if [ -z "$INSTANCES" ]; then
        echo "# ⚠️  No instances found in terraform output"
    else
        echo "$INSTANCES"
    fi
    
    echo ""
    echo "[jenkins_servers:vars]"
    echo "ansible_python_interpreter=/usr/bin/python3"
    echo "ansible_connection=ssh"
    echo "ansible_port=22"
    echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
    
} > "$OUTPUT_FILE"

echo "✅ Inventory generated successfully at $OUTPUT_FILE"
