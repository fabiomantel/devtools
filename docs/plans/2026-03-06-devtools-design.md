# devtools CLI — Design

**Date:** 2026-03-06

## Overview

A single executable zsh script that presents an fzf menu of developer tools, each backed by an existing zsh function in `~/.zsh_functions/`.

## Tools

| Menu label | Function | Source file |
|---|---|---|
| Claude Sessions | `claude-sessions` | `claude-sessions.zsh` |
| Claude History | `claude-history` | `claude-history.zsh` |
| Git Status | `gst` | `git-status-overview.zsh` |
| LiteLLM Budget | `budget` | `litellm-budget.zsh` |

## File layout

```
~/Development/devtools/
├── docs/plans/          # this file
└── devtools             # the executable script
```

Symlinked: `~/bin/devtools -> ~/Development/devtools/devtools`

## Script behaviour

1. Sources all 4 `~/.zsh_functions/*.zsh` files
2. Shows an fzf menu (prompt, rounded border, 40% height)
3. Runs the selected tool's function in the same shell

## Dependencies

- `zsh`
- `fzf`
- `jq`, `python3` (required by `claude-history`)
- `gh` (required by `gst`)
- `curl` (required by `budget`)
- `$ANTHROPIC_AUTH_TOKEN` env var (required by `budget`)
