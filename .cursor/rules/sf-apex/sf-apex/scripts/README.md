# sf-apex Validation Scripts

These scripts provide validation for sf-apex files. In Claude Code,
they run automatically via PostToolUse hooks. For other CLIs, run them manually.

## Usage

```bash
# Validate a file
python scripts/validate_*.py path/to/your/file

# Example for Apex
python scripts/validate_apex.py MyClass.cls
```

## Available Scripts

- `apex-lsp-validate.py` - Apex LSP Validation Hook
- `naming_validator.py` - Naming Convention Validator for Salesforce Flows (v2.0.0)
- `post-tool-validate.py` - Post-Tool Validation Hook for sf-apex plugin.
- `post-write-validate.py` - Post-Write Validation Hook for sf-apex plugin.
- `security_validator.py` - Security Validator for Salesforce Flows
- `validate_apex.py` - Apex Validator for sf-skills plugin.

## Requirements

- Python 3.8+
- Dependencies vary by script (check imports)

## Note

These scripts were originally designed as Claude Code hooks.
They accept file paths as command-line arguments for manual use.
