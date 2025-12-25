# Prevent Destructive Commands

A safety framework for preventing AI agents (like Claude Code) from executing destructive commands. This repository provides hooks and configuration files that block dangerous operations before they can cause harm.

## Overview

When using AI coding assistants, there's a risk that they might execute destructive commands like:
- `rm -rf /` - Recursive force delete
- `git reset --hard` - Discard all uncommitted changes
- `git push --force` - Overwrite remote history
- `DROP DATABASE` - Delete entire databases
- And many more...

This repository provides pre-configured hooks that intercept these commands and block them before execution.

## Features

- **PreToolUse Hooks**: Scripts that run before any command execution
- **Cross-Platform Support**: Both Bash (Linux/macOS/WSL) and PowerShell (Windows) scripts
- **Comprehensive Pattern Matching**: Blocks 50+ destructive command patterns
- **Categorized Protection**: File deletion, Git operations, database commands, Docker, and system-level operations
- **Configurable Permissions**: Allow, deny, or ask for specific command patterns

## Blocked Command Categories

| Category | Examples |
|----------|----------|
| File Deletion | `rm -rf`, `del /s`, `Remove-Item -Recurse -Force` |
| Git Destructive | `git reset --hard`, `git push --force`, `git clean -f` |
| GitHub CLI | `gh repo delete`, `gh release delete` |
| Database | `DROP DATABASE`, `DROP TABLE`, `TRUNCATE`, `DELETE FROM` |
| Docker | `docker system prune`, `docker volume rm` |
| System | `mkfs`, `dd`, `chmod -R 777 /` |
| NPM/Node | `npm cache clean --force` |

## Installation

### For Claude Code

1. **Copy the `.claude` folder** to your project root:

```
your-project/
├── .claude/
│   ├── settings.json          # Hook configuration
│   ├── settings.unix.json     # Hook configuration (macOS/Linux/WSL)
│   ├── settings.local.json    # Your local permissions (create from example)
│   └── hooks/
│       ├── block-destructive.sh    # Bash script
│       └── block-destructive.ps1   # PowerShell script
```

2. **Pick the right hook config for your OS**:

   - **Windows (PowerShell)**: keep `.claude/settings.json` as-is.
   - **macOS/Linux/WSL (Bash)**: copy `.claude/settings.unix.json` over `.claude/settings.json`.
     - Requires `jq` to be installed (used to parse the hook JSON input).

3. **Create your local settings**:

   Copy the example file and customize it for your needs:
   ```bash
   cp .claude/settings.local.json.example .claude/settings.local.json
   ```

4. **Customize permissions** in `settings.local.json`:
   - `allow`: Commands that execute without prompting
   - `deny`: Commands that are always blocked
   - `ask`: Commands that require user confirmation

### File Descriptions

| File | Purpose |
|------|---------|
| `settings.json` | Main hook configuration - registers the PreToolUse hook (Windows/PowerShell by default) |
| `settings.unix.json` | Alternate hook configuration (macOS/Linux/WSL) |
| `settings.local.json.example` | Template for local permissions (copy to `settings.local.json`) |
| `hooks/block-destructive.sh` | Bash script with destructive command patterns |
| `hooks/block-destructive.ps1` | PowerShell script with destructive command patterns |

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude Code Agent                           │
│                                                                 │
│  1. Agent decides to run: git reset --hard                      │
│                          ↓                                      │
│  2. PreToolUse hook triggered                                   │
│                          ↓                                      │
│  3. block-destructive.ps1 / .sh receives command               │
│                          ↓                                      │
│  4. Pattern matching against 50+ destructive patterns          │
│                          ↓                                      │
│  5a. Match found → EXIT 2 (blocked) → Command NOT executed     │
│  5b. No match    → EXIT 0 (allowed) → Command executes         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Customization

### Adding New Patterns

Edit the hook scripts to add new patterns:

**Bash (`block-destructive.sh`):**
```bash
destructive_patterns=(
    # Add your pattern here
    'your-command-pattern|||Description of the command'
)
```

**PowerShell (`block-destructive.ps1`):**
```powershell
$destructivePatterns = @(
    # Add your pattern here
    @{ Pattern = 'your-command-pattern'; Desc = 'Description of the command' }
)
```

### Permission Levels in settings.local.json

```json
{
  "permissions": {
    "allow": [
      "Bash(safe-command:*)"
    ],
    "deny": [
      "Bash(dangerous-command:*)"
    ],
    "ask": [
      "Bash(risky-command:*)"
    ]
  }
}
```

## Exit Codes

The hook scripts use specific exit codes:
- `0` - Allow the command to execute
- `2` - Block the command (stderr shown to AI agent)

## Contributing

Contributions are welcome! If you have additional destructive patterns to add or improvements to the scripts, please:

1. Fork the repository
2. Create a feature branch
3. Add your patterns or improvements
4. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built to help the AI coding community stay safe while leveraging the power of AI assistants.

