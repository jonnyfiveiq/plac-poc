#!/usr/bin/env python3
"""
Schema validation placeholder for Phase 2
Currently performs basic YAML syntax validation
"""

import sys
import yaml


def validate_schema(state_file):
    """Validate desired state file (placeholder for Phase 2 JSON Schema validation)"""
    try:
        with open(state_file, 'r') as f:
            data = yaml.safe_load(f)

        if not data:
            print(f"ERROR: {state_file} is empty or invalid YAML", file=sys.stderr)
            return False

        # Basic structure checks
        if 'apiVersion' not in data:
            print("WARNING: apiVersion field missing (recommended)", file=sys.stderr)

        print(f"✓ {state_file} is valid YAML")
        print("NOTE: Full JSON Schema validation will be added in Phase 2")
        return True

    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML syntax in {state_file}:", file=sys.stderr)
        print(f"  {e}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print(f"ERROR: File not found: {state_file}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: Validation failed: {e}", file=sys.stderr)
        return False


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <desired-state-file>", file=sys.stderr)
        sys.exit(1)

    success = validate_schema(sys.argv[1])
    sys.exit(0 if success else 1)
