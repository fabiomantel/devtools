# devtools CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a single executable zsh script at `~/Development/devtools/devtools` that shows an fzf menu of 4 developer tools and runs the selected one.

**Architecture:** One zsh script sources the 4 existing `~/.zsh_functions/*.zsh` files, presents an fzf menu, and dispatches to the selected function. A `~/bin/` directory is created and the script is symlinked into it so `devtools` is available on PATH.

**Tech Stack:** zsh, fzf

---

### Task 1: Create the devtools script

**Files:**
- Create: `/Users/fabio.mantelmacher/Development/devtools/devtools`

**Step 1: Write the script**

```zsh
#!/usr/bin/env zsh
# devtools — fzf launcher for developer tools
#
# Requires: fzf
# Sources:  ~/.zsh_functions/{claude-sessions,claude-history,git-status-overview,litellm-budget}.zsh

source ~/.zsh_functions/claude-sessions.zsh
source ~/.zsh_functions/claude-history.zsh
source ~/.zsh_functions/git-status-overview.zsh
source ~/.zsh_functions/litellm-budget.zsh

choice=$(printf '%s\n' \
  "Claude Sessions" \
  "Claude History" \
  "Git Status" \
  "LiteLLM Budget" \
  | fzf \
      --prompt="devtools > " \
      --height=40% \
      --border=rounded \
      --header="Select a tool  (esc to cancel)" \
      --no-multi)

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "Claude Sessions") claude-sessions ;;
  "Claude History")  claude-history ;;
  "Git Status")      gst ;;
  "LiteLLM Budget")  budget ;;
esac
```

**Step 2: Make it executable**

```bash
chmod +x /Users/fabio.mantelmacher/Development/devtools/devtools
```

**Step 3: Verify the file is executable**

```bash
ls -la /Users/fabio.mantelmacher/Development/devtools/devtools
```

Expected: `-rwxr-xr-x` permissions.

---

### Task 2: Put it on PATH

**Step 1: Create ~/bin if it doesn't exist**

```bash
mkdir -p ~/bin
```

**Step 2: Symlink the script**

```bash
ln -sf /Users/fabio.mantelmacher/Development/devtools/devtools ~/bin/devtools
```

**Step 3: Verify the symlink**

```bash
ls -la ~/bin/devtools
```

Expected: `~/bin/devtools -> /Users/fabio.mantelmacher/Development/devtools/devtools`

**Step 4: Ensure ~/bin is on PATH**

Check if `~/bin` is already in PATH:

```bash
echo $PATH | tr ':' '\n' | grep -q "$HOME/bin" && echo "already on PATH" || echo "need to add"
```

If "need to add", append to `~/.zshrc`:

```zsh
# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"
```

Then reload:

```bash
source ~/.zshrc
```

**Step 5: Verify the command is reachable**

```bash
which devtools
```

Expected: `/Users/fabio.mantelmacher/bin/devtools`

---

### Task 3: Smoke test

**Step 1: Run the command**

```bash
devtools
```

Expected: fzf menu appears with 4 options. Select "LiteLLM Budget" — it should show the spend/budget output. Press Esc — should exit cleanly with no error.

**Step 2: Verify Esc exits cleanly**

Run `devtools`, press Esc.

Expected: returns to shell prompt, exit code 0.
