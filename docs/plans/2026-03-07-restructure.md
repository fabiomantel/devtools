# devtools Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate all zsh plugin scripts into the devtools repo, remove global sourcing from `.zshrc`, add `install.sh`, init git, and write a README.

**Architecture:** Move `~/.zsh_functions/*.zsh` → `~/Development/devtools/plugins/`. Update `devtools` to source plugins relative to itself. Add `install.sh` to automate symlink + `.zshrc` edits. Git-init the repo and document everything in `README.md`.

**Tech Stack:** zsh, git

---

### Task 1: Create the plugins/ directory and move scripts

**Files:**
- Create dir: `~/Development/devtools/plugins/`
- Move: `~/.zsh_functions/claude-history.zsh`
- Move: `~/.zsh_functions/claude-sessions.zsh`
- Move: `~/.zsh_functions/git-status-overview.zsh`
- Move: `~/.zsh_functions/litellm-budget.zsh`

**Step 1: Create the directory**

```bash
mkdir -p /Users/fabio.mantelmacher/Development/devtools/plugins
```

**Step 2: Move the four plugin files**

```bash
mv /Users/fabio.mantelmacher/.zsh_functions/claude-history.zsh \
   /Users/fabio.mantelmacher/Development/devtools/plugins/

mv /Users/fabio.mantelmacher/.zsh_functions/claude-sessions.zsh \
   /Users/fabio.mantelmacher/Development/devtools/plugins/

mv /Users/fabio.mantelmacher/.zsh_functions/git-status-overview.zsh \
   /Users/fabio.mantelmacher/Development/devtools/plugins/

mv /Users/fabio.mantelmacher/.zsh_functions/litellm-budget.zsh \
   /Users/fabio.mantelmacher/Development/devtools/plugins/
```

**Step 3: Verify**

```bash
ls /Users/fabio.mantelmacher/Development/devtools/plugins/
```

Expected output:
```
claude-history.zsh  claude-sessions.zsh  git-status-overview.zsh  litellm-budget.zsh
```

**Step 4: Verify ~/.zsh_functions is now empty**

```bash
ls /Users/fabio.mantelmacher/.zsh_functions/
```

Expected: empty output (or directory not found).

---

### Task 2: Update the devtools script to source from plugins/

**Files:**
- Modify: `~/Development/devtools/devtools`

The script currently hardcodes `~/.zsh_functions/`. Change it to resolve plugins relative to the script's own real path (so the `~/bin/devtools` symlink works correctly).

**Step 1: Replace the source block**

Replace lines 9–12 in `devtools`:

Old:
```zsh
source ~/.zsh_functions/claude-sessions.zsh     || { echo "Error: missing claude-sessions.zsh" >&2;     exit 1 }
source ~/.zsh_functions/claude-history.zsh      || { echo "Error: missing claude-history.zsh" >&2;      exit 1 }
source ~/.zsh_functions/git-status-overview.zsh || { echo "Error: missing git-status-overview.zsh" >&2; exit 1 }
source ~/.zsh_functions/litellm-budget.zsh      || { echo "Error: missing litellm-budget.zsh" >&2;      exit 1 }
```

New (insert after the shebang comment block, replacing the old sources):
```zsh
# Resolve the real directory of this script, even when called through a symlink
_DEVTOOLS_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

source "$_DEVTOOLS_DIR/plugins/claude-sessions.zsh"     || { echo "Error: missing claude-sessions.zsh" >&2;     exit 1 }
source "$_DEVTOOLS_DIR/plugins/claude-history.zsh"      || { echo "Error: missing claude-history.zsh" >&2;      exit 1 }
source "$_DEVTOOLS_DIR/plugins/git-status-overview.zsh" || { echo "Error: missing git-status-overview.zsh" >&2; exit 1 }
source "$_DEVTOOLS_DIR/plugins/litellm-budget.zsh"      || { echo "Error: missing litellm-budget.zsh" >&2;      exit 1 }
```

**Step 2: Verify the file looks correct**

```bash
head -20 /Users/fabio.mantelmacher/Development/devtools/devtools
```

Expected: shebang on line 1, `_DEVTOOLS_DIR` assignment, then four source lines using `$_DEVTOOLS_DIR/plugins/`.

---

### Task 3: Create install.sh

**Files:**
- Create: `~/Development/devtools/install.sh`

**Step 1: Write the script**

```zsh
#!/usr/bin/env zsh
# install.sh — wire devtools into your shell
#
# Run once after cloning:  zsh install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVTOOLS_BIN="$REPO_DIR/devtools"
BIN_DIR="$HOME/bin"
LINK="$BIN_DIR/devtools"
ZSHRC="$HOME/.zshrc"

echo "==> devtools installer"

# 1. Create ~/bin if needed
if [[ ! -d "$BIN_DIR" ]]; then
  mkdir -p "$BIN_DIR"
  echo "  created $BIN_DIR"
fi

# 2. Symlink devtools into ~/bin
if [[ -L "$LINK" || -e "$LINK" ]]; then
  rm "$LINK"
fi
ln -s "$DEVTOOLS_BIN" "$LINK"
echo "  symlinked $LINK -> $DEVTOOLS_BIN"

# 3. Add ~/bin to PATH in .zshrc if not already there
if ! grep -qF 'export PATH="$HOME/bin:$PATH"' "$ZSHRC"; then
  echo '\n# devtools\nexport PATH="$HOME/bin:$PATH"' >> "$ZSHRC"
  echo "  added ~/bin to PATH in $ZSHRC"
else
  echo "  ~/bin already on PATH in $ZSHRC (skipped)"
fi

# 4. Remove the old global ~/.zsh_functions sourcing loop from .zshrc
if grep -qF 'for f in ~/.zsh_functions/*.zsh' "$ZSHRC"; then
  # Remove the two-line block: the comment line + the for loop line
  sed -i '' '/# Custom Functions/d' "$ZSHRC"
  sed -i '' '/for f in ~\/.zsh_functions\/\*\.zsh/d' "$ZSHRC"
  echo "  removed ~/.zsh_functions sourcing loop from $ZSHRC"
else
  echo "  no ~/.zsh_functions loop found in $ZSHRC (skipped)"
fi

echo ""
echo "Done. Run:  source ~/.zshrc"
echo "Then test:  devtools"
```

**Step 2: Make it executable**

```bash
chmod +x /Users/fabio.mantelmacher/Development/devtools/install.sh
```

**Step 3: Verify**

```bash
ls -la /Users/fabio.mantelmacher/Development/devtools/install.sh
```

Expected: `-rwxr-xr-x`

---

### Task 4: Run install.sh and verify .zshrc

**Step 1: Run the installer**

```bash
zsh /Users/fabio.mantelmacher/Development/devtools/install.sh
```

Expected output:
```
==> devtools installer
  symlinked /Users/fabio.mantelmacher/bin/devtools -> /Users/fabio.mantelmacher/Development/devtools/devtools
  ~/bin already on PATH in /Users/fabio.mantelmacher/.zshrc (skipped)
  removed ~/.zsh_functions sourcing loop from /Users/fabio.mantelmacher/.zshrc

Done. Run:  source ~/.zshrc
Then test:  devtools
```

**Step 2: Verify the symlink**

```bash
ls -la /Users/fabio.mantelmacher/bin/devtools
```

Expected: `lrwxr-xr-x ... /Users/fabio.mantelmacher/bin/devtools -> /Users/fabio.mantelmacher/Development/devtools/devtools`

**Step 3: Verify .zshrc no longer has the sourcing loop**

```bash
grep -n 'zsh_functions' /Users/fabio.mantelmacher/.zshrc
```

Expected: no output.

**Step 4: Verify ~/bin PATH entry is present**

```bash
grep -n 'HOME/bin' /Users/fabio.mantelmacher/.zshrc
```

Expected: one line with `export PATH="$HOME/bin:$PATH"`.

---

### Task 5: Write README.md

**Files:**
- Create: `~/Development/devtools/README.md`

```markdown
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
git clone <repo-url> ~/Development/devtools
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
2. Source it in `devtools` (add a line with the others).
3. Add a menu entry to the `printf` list and a `case` branch to call your function.

### Example plugin

```zsh
# plugins/hello.zsh
hello() {
  echo "Hello, world!"
}
```

In `devtools`:
```zsh
source "$_DEVTOOLS_DIR/plugins/hello.zsh" || { echo "Error: missing hello.zsh" >&2; exit 1 }
```

```zsh
printf '%s\n' \
  ...
  "Hello"
```

```zsh
"Hello") hello ;;
```

## Structure

```
devtools/
├── plugins/          # one .zsh file per tool
├── devtools          # main CLI entry point
├── install.sh        # one-time setup script
├── docs/plans/       # design and implementation docs
└── README.md
```
```

---

### Task 6: Git init and initial commit

**Step 1: Init the repo**

```bash
cd /Users/fabio.mantelmacher/Development/devtools && git init
```

Expected: `Initialized empty Git repository in .../devtools/.git/`

**Step 2: Add all files**

```bash
cd /Users/fabio.mantelmacher/Development/devtools && git add devtools install.sh README.md plugins/ docs/
```

**Step 3: Commit**

```bash
cd /Users/fabio.mantelmacher/Development/devtools && git commit -m "feat: consolidate plugins into repo, add install.sh and README"
```

Expected: commit summary listing all added files.

**Step 4: Verify**

```bash
cd /Users/fabio.mantelmacher/Development/devtools && git log --oneline
```

Expected: one commit line with the message above.
