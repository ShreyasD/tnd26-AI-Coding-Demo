# sf-lwc Validation Scripts

These scripts provide validation for sf-lwc files. In Claude Code,
they run automatically via PostToolUse hooks. For other CLIs, run them manually.

## Usage

```bash
# Validate a file
python scripts/validate_*.py path/to/your/file

# Example for Apex
python scripts/validate_apex.py MyClass.cls
```

## Available Scripts

- `post-tool-validate.py` - Post-Tool Validation Hook for sf-lwc plugin.
- `slds_linter_wrapper.py` - Wrapper for official @salesforce-ux/slds-linter npm package.
- `validate_slds.py` - SLDS 2 Validator for Lightning Web Components.

## Requirements

- Python 3.8+
- Dependencies vary by script (check imports)

## Note

These scripts were originally designed as Claude Code hooks.
They accept file paths as command-line arguments for manual use.
