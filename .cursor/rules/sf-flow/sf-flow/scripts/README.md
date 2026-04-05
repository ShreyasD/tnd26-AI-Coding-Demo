# sf-flow Validation Scripts

These scripts provide validation for sf-flow files. In Claude Code,
they run automatically via PostToolUse hooks. For other CLIs, run them manually.

## Usage

```bash
# Validate a file
python scripts/validate_*.py path/to/your/file

# Example for Apex
python scripts/validate_apex.py MyClass.cls
```

## Available Scripts

- `naming_validator.py` - Naming Convention Validator for Salesforce Flows (v2.0.0)
- `post-tool-validate.py` - Post-Tool Validation Hook for sf-flow plugin.
- `post-write-validate.py` - Post-Write Validation Hook for sf-flow plugin.
- `security_validator.py` - Security Validator for Salesforce Flows
- `simulate_flow.py` - Salesforce Flow Simulator - Bulk Testing & Governor Limit Analysis (v2.1.0)
- `validate_flow.py` - import xml.etree.ElementTree as ET

## Requirements

- Python 3.8+
- Dependencies vary by script (check imports)

## Note

These scripts were originally designed as Claude Code hooks.
They accept file paths as command-line arguments for manual use.
