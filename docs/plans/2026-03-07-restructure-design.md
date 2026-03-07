# devtools Restructure — Design

**Date:** 2026-03-07

## Goal

Consolidate all zsh plugin scripts into the devtools repo. Remove global sourcing from `.zshrc`. Provide an `install.sh` that wires everything up automatically.

## Final Structure

```
~/Development/devtools/
├── plugins/
│   ├── claude-history.zsh
│   ├── claude-sessions.zsh
│   ├── git-status-overview.zsh
│   └── litellm-budget.zsh
├── devtools             ← main CLI entry point
├── install.sh           ← sets up symlink + .zshrc PATH entry
├── docs/plans/
└── README.md
```

## Changes

### `~/.zsh_functions/` → `plugins/`
Move all four `.zsh` files into `devtools/plugins/`. The old directory is left empty.

### `devtools` script
Sources plugins via `$(dirname $(readlink -f $0))/plugins/*.zsh` so it resolves correctly through the `~/bin/devtools` symlink.

### `install.sh`
1. Creates `~/bin/` if missing
2. Symlinks `~/bin/devtools → ~/Development/devtools/devtools`
3. Appends `export PATH="$HOME/bin:$PATH"` to `~/.zshrc` if not already present
4. Removes the old `for f in ~/.zsh_functions/*.zsh` sourcing line from `.zshrc`
5. Prints instructions to `source ~/.zshrc`

### git + README
- `git init` in repo root
- Initial commit with all files
- `README.md` with prerequisites, install steps, plugin authoring guide, and usage example

## Decisions

- Functions are CLI-only — not sourced globally
- Artifacts (`~/.claude/`, etc.) stay in `~/` unchanged
- `~/bin/devtools` symlink pattern retained (Option C adds `install.sh` on top)
