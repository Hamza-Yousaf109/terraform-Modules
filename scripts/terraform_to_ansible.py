import json
import sys
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 terraform_to_ansible.py <input-json> <output-file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        with open(input_file, "r") as f:
            outputs = json.load(f)

        inventory_lines = ["# Auto-generated inventory", ""]
        inventory_lines.append("[jenkins_servers]")

        instances = outputs.get("instances_with_ssh", {}).get("instances", [])

        for instance in instances:
            line = f"{instance['name']} ansible_host={instance['ansible_host']} ansible_user={instance['ansible_user']}"
            inventory_lines.append(line)

        inventory_lines.append("")
        inventory_lines.append("[jenkins_servers:vars]")
        inventory_lines.append("ansible_python_interpreter=/usr/bin/python3")
        inventory_lines.append("ansible_connection=ssh")
        inventory_lines.append("ansible_port=22")
        inventory_lines.append("ansible_ssh_common_args='-o StrictHostKeyChecking=no'")

        Path(output_file).parent.mkdir(parents=True, exist_ok=True)

        with open(output_file, "w") as f:
            f.write("\n".join(inventory_lines))

        print("Inventory generated successfully")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()