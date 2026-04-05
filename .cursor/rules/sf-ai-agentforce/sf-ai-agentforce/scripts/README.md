# sf-ai-agentforce Validation Scripts

These scripts provide validation for sf-ai-agentforce files. In Claude Code,
they run automatically via PostToolUse hooks. For other CLIs, run them manually.

## Usage

```bash
# Validate a file
python scripts/validate_*.py path/to/your/file

# Example for Apex
python scripts/validate_apex.py MyClass.cls
```

## Available Scripts

- `agentscript-lsp-validate.py` - Agent Script LSP Validation Hook

## Requirements

- Python 3.8+
- Dependencies vary by script (check imports)

## Note

These scripts were originally designed as Claude Code hooks.
They accept file paths as command-line arguments for manual use.
