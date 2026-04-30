#!/usr/bin/env python3

import json
import sys
from pathlib import Path

def main():

    if len(sys.argv) < 3:
        print("Usage: python3 terraform_to_ansible.py <tf-output.json> <output-file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    try:
        with open(input_file, "r") as f:
            outputs = json.load(f)

        inventory = []
        inventory.append("# Auto generated inventory")
        inventory.append("")
        inventory.append("[jenkins_servers]")

        # Example structure safe parsing
        if "instances_with_ssh" in outputs:
            instances = outputs["instances_with_ssh"]["value"].get("instances", [])

            for i in instances:
                inventory.append(
                    f"{i['name']} ansible_host={i['ansible_host']} ansible_user={i['ansible_user']}"
                )

        inventory.append("")
        inventory.append("[jenkins_servers:vars]")
        inventory.append("ansible_python_interpreter=/usr/bin/python3")
        inventory.append("ansible_connection=ssh")

        Path(output_file).parent.mkdir(parents=True, exist_ok=True)

        with open(output_file, "w") as f:
            f.write("\n".join(inventory))

        print("Inventory generated successfully")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()