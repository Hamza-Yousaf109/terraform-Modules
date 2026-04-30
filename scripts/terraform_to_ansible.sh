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

echo "📍 Processing Terraform output..."
echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"

# Debug: Show raw output structure
echo ""
echo "🔍 Available keys in terraform output:"
jq 'keys' "$INPUT_FILE" 2>/dev/null || echo "Failed to parse JSON"

echo ""
echo "🔍 Full terraform output:"
jq '.' "$INPUT_FILE" 2>/dev/null || cat "$INPUT_FILE"

# Try multiple methods to extract instances
echo ""
echo "🔎 Attempting to extract instances..."

# Method 1: Direct path
INSTANCES=$(jq -r '.instances_with_ssh.value.instances[]? | select(. != null) | "\(.name) ansible_host=\(.ansible_host) ansible_user=\(.ansible_user)"' "$INPUT_FILE" 2>/dev/null || echo "")

if [ -z "$INSTANCES" ]; then
    echo "⚠️  Method 1 failed, trying alternative paths..."
    
    # Method 2: Check if instances_with_ssh exists at root level
    INSTANCES=$(jq -r '.instances_with_ssh[0].instances[]? | select(. != null) | "\(.name) ansible_host=\(.ansible_host) ansible_user=\(.ansible_user)"' "$INPUT_FILE" 2>/dev/null || echo "")
fi

# Generate inventory file
{
    echo "# Auto-generated inventory"
    echo ""
    echo "[jenkins_servers]"
    
    if [ -z "$INSTANCES" ]; then
        echo "# ⚠️  No instances found in terraform output"
        echo "# Check terraform apply output to verify instances were created"
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

echo ""
echo "✅ Inventory generated at $OUTPUT_FILE"
