# devtools

An fzf-powered CLI launcher for personal developer tools.

## Prerequisites

- zsh
- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [jq](https://stedolan.github.io/jq/) — `brew install jq`
- [gh](https://cli.github.com/) — `brew install gh`
- python3 — `brew install python`
- curl — included on macOS
- `$ANTHROPIC_AUTH_TOKEN` env var (used by the LiteLLM Budget plugin)

## Install

```zsh
git clone https://github.com/fabiomantel/devtools ~/Development/devtools
cd ~/Development/devtools
zsh install.sh
source ~/.zshrc
```

## Usage

```
devtools
```

An interactive fzf menu appears. Navigate with arrow keys, select with Enter, quit with Esc.

| Menu item | What it does |
|---|---|
| Claude Sessions | Browse and resume Claude Code sessions |
| Claude History | View Claude conversation history |
| Git Status | Overview of all local git repos |
| LiteLLM Budget | Show API spend vs budget |

## Adding a plugin

1. Create `plugins/your-plugin.zsh` — define one or more shell functions inside it.
2. Source it in `devtools` (add a line alongside the existing source lines).
3. Add a menu entry to the `printf` list and a `case` branch to call your function.

### Example plugin

**plugins/hello.zsh**
```zsh
hello() {
  echo "Hello, world!"
}
```

**devtools** — add source line:
```zsh
source "$_DEVTOOLS_DIR/plugins/hello.zsh" || { echo "Error: missing hello.zsh" >&2; exit 1 }
```

**devtools** — add menu entry to the `printf` block:
```zsh
"Hello"
```

**devtools** — add case branch:
```zsh
"Hello") hello ;;
```

## Structure

```
devtools/
├── plugins/          # one .zsh file per tool
│   ├── claude-history.zsh
│   ├── claude-sessions.zsh
│   ├── git-status-overview.zsh
│   └── litellm-budget.zsh
├── devtools          # main CLI entry point
├── install.sh        # one-time setup script
├── docs/plans/       # design and implementation docs
└── README.md
```
