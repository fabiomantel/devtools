# CLAUDE.md

> **Source file:** `AGENTS.md` is the source of truth. `CLAUDE.md` is a symlink to it — edit `AGENTS.md` only.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An fzf-powered CLI launcher (`devtools`) for personal developer tools. Written entirely in zsh with no build system. Run `devtools` to open an interactive fzf menu; each menu item calls a function defined in a plugin.

## Install / setup

```zsh
zsh install.sh   # symlinks devtools into ~/bin and adds ~/bin to PATH
source ~/.zshrc
devtools
```

## Architecture

- **`devtools`** — the main entry point. Sources all plugins, defines `_devtools_run` (a spinner wrapper for non-interactive commands), then loops an fzf menu dispatching to plugin functions.
- **`plugins/*.zsh`** — one file per tool; each defines one or more shell functions. Currently:
  - `claude-sessions.zsh` → `claude-sessions()` — reads `~/.claude/projects/` JSONL files to show running Claude Code processes with token cost (priced for claude-sonnet-4-6).
  - `claude-history.zsh` → `claude-history()` — fzf browser for past Claude sessions with rename/delete/resume (calls `claude --resume <uuid>`). The project key ↔ path encoding/decoding logic lives in `_ch_encode_project_key` / `_ch_decode_project_key`.
  - `git-status-overview.zsh` → `gst()` — rich git status across main worktree + all active worktrees, including PR state via `gh`.
  - `litellm-budget.zsh` → `budget()` — queries internal LiteLLM API using `$ANTHROPIC_AUTH_TOKEN`.

## Adding a plugin

1. Create `plugins/your-plugin.zsh` with the shell function(s).
2. In `devtools`, add a `source` line alongside the existing ones.
3. Add the menu label to the `printf '%s\n'` block.
4. Add a `case` branch calling your function (wrap with `_devtools_run "Label" fn_name` if the function is non-interactive and benefits from a spinner).

## GitHub interactions

Always use the `gh` CLI for GitHub operations (PRs, issues, checks, releases) rather than the API directly or web URLs.

## Known quirk

`claude-history.zsh` fzf `--reload` and `--preview` bindings reference `~/.zsh_functions/claude-history.zsh` (a legacy path). If reload/preview breaks after install, that path needs to be updated to point to the repo's actual location.
