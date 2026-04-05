# sf-ai-agentforce-testing Validation Scripts

These scripts provide validation for sf-ai-agentforce-testing files. In Claude Code,
they run automatically via PostToolUse hooks. For other CLIs, run them manually.

## Usage

```bash
# Validate a file
python scripts/validate_*.py path/to/your/file

# Example for Apex
python scripts/validate_apex.py MyClass.cls
```

## Available Scripts

- `generate-test-spec.py` - Generate Agentforce test specs from Agent Script (.agent) files.
- `parse-agent-test-results.py` - Parse Agentforce test results and format for Claude auto-fix loop.
- `run-automated-tests.py` - Automated Agentforce Agent Testing Orchestrator.

## Requirements

- Python 3.8+
- Dependencies vary by script (check imports)

## Note

These scripts were originally designed as Claude Code hooks.
They accept file paths as command-line arguments for manual use.
