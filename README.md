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
| Budget | Show LiteLLM key, user, and team spend vs budget |
| Git Status | Overview of all local git repos |
| Claude Sessions | Browse and resume Claude Code sessions |
| Claude History | View Claude conversation history |

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

## Chrome Extension

A popup extension that shows all your AI budget usage in one place — LiteLLM, GitHub Copilot, and Cursor.

### Install

1. Open `chrome://extensions/`
2. Enable **Developer mode** (top-right toggle)
3. Click **Load unpacked** → select `chrome-extension/`

### Configure

Click the extension icon → **Configure** (first run) or the ⚙️ gear icon:

| Field | Value |
|---|---|
| API Base URL | Your `ANTHROPIC_BASE_URL` (e.g. `https://your-litellm-instance.com`) |
| Auth Token | Your `ANTHROPIC_AUTH_TOKEN` (or run `aura login`) |
| GitHub Token | Output of `gh auth token` — for Copilot quota |

**Cursor** uses your browser session automatically — just be logged in to [cursor.com](https://cursor.com) in the same Chrome profile.

### What it shows

| Section | Data |
|---|---|
| 🤖 LiteLLM | Key spend vs budget, lifetime user spend, team budget — all with progress bars |
| 🐙 GitHub Copilot | Premium interactions, chat, completions quotas (plan: business) |
| 🖱️ Cursor | Per-model request usage (fast, premium, etc.) |

## Structure

```
devtools/
├── chrome-extension/ # Chrome popup extension
│   ├── manifest.json
│   ├── popup.html
│   ├── popup.css
│   ├── popup.js
│   └── icons/
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
