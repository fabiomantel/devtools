# claude-history.zsh
# Usage: claude-history [project-dir-path]
#
# Requires: fzf, jq, python3

# ── Helpers ────────────────────────────────────────────────────────────────────

# Decode a ~/.claude/projects/ directory key back to a readable path.
# Input:  "-Users-fab-Development-my-repo"
# Output: "/Users/fab/Development/my-repo"  (then collapsed to ~/...)
_ch_decode_project_key() {
  local key="$1"
  # Fix 1: guard against empty input
  [[ -z "$key" ]] && return 0
  local body="${key#-}"

  # Recursively descend the filesystem to resolve the ambiguous encoding.
  # Both "/" and "." are encoded as "-", so we cannot decode purely textually.
  # _ch_resolve <remaining-encoded> <current-real-path> — prints matching real paths.
  _ch_resolve() {
    local encoded="$1"
    local current="$2"
    if [[ -z "$encoded" ]]; then
      echo "$current"
      return
    fi
    local child name name_enc
    for child in "$current"/*(ND/); do
      child="${child%/}"
      [[ -e "$child" ]] || continue
      name="${child##*/}"
      # Claude Code encodes /, ., and _ all as -
      name_enc="${name//[\/._]/-}"
      if [[ "$encoded" == "$name_enc" ]]; then
        _ch_resolve "" "$child"
      elif [[ "$encoded" == "${name_enc}-"* ]]; then
        _ch_resolve "${encoded#${name_enc}-}" "$child"
      fi
    done
  }

  local resolved
  # Fix 2: take only the first match to avoid multi-line output
  resolved=$(_ch_resolve "$body" "" | head -1)
  # Fix 3: unset _ch_resolve so it doesn't leak into global scope
  unfunction _ch_resolve 2>/dev/null
  [[ -z "$resolved" ]] && return 0
  resolved="/${resolved#/}"   # normalise double leading slash

  # Collapse home dir prefix
  resolved="${resolved/#$HOME/~}"
  echo "$resolved"
}

# Given an absolute project path, return the ~/.claude/projects/ key.
# Input:  "/Users/fab/Development/my-repo"
# Output: "-Users-fab-Development-my-repo"
_ch_encode_project_key() {
  local dir="$1"
  # Expand ~ if present
  dir="${dir/#\~/$HOME}"
  echo "$dir" | tr '/._' '-'
}

# Extract metadata from a single session JSONL file.
# Output (tab-separated): uuid  date  display_name  first_message
_ch_session_meta() {
  local file="$1"
  local uuid
  uuid=$(basename "$file" .jsonl)

  python3 - "$file" "$uuid" << 'PYEOF'
import sys, json

file_path = sys.argv[1]
uuid = sys.argv[2]

custom_title = ""
slug = ""
first_msg = ""
first_ts = ""

try:
    with open(file_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue

            # Timestamp of first entry
            if not first_ts and obj.get("timestamp"):
                first_ts = obj["timestamp"][:10]  # YYYY-MM-DD

            # Custom title (last wins)
            if obj.get("type") == "custom-title" and obj.get("customTitle"):
                custom_title = obj["customTitle"]

            # Slug (last wins)
            if obj.get("slug"):
                slug = obj["slug"]

            # First real user message
            if not first_msg and obj.get("type") == "user":
                msg = obj.get("message") or {}
                content = msg.get("content") or []
                for block in (content if isinstance(content, list) else []):
                    text = block.get("text", "") if isinstance(block, dict) else ""
                    text = text.strip()
                    # Skip system/skill noise
                    if text and not text.startswith("Base directory for this skill") \
                              and not text.startswith("[Request interrupted") \
                              and not text.startswith("#"):
                        first_msg = text[:120].replace("\t", " ").replace("\n", " ")
                        break

except Exception as e:
    pass

display = custom_title or slug or first_msg or uuid
date = first_ts or "unknown"

# Skip snapshot-only sessions (no timestamp, no name, no message — just internal bookkeeping)
if date == "unknown" and not custom_title and not slug and not first_msg:
    sys.exit(0)

print(f"{uuid}\t{date}\t{display}\t{first_msg}")
PYEOF
}

# List all sessions in a project directory, sorted newest-first.
# Arg: project_key (the ~/.claude/projects/ subdirectory name)
# Output (tab-separated per line): uuid  date  display_name  first_msg
_ch_list_sessions() {
  local proj_key="$1"
  local proj_dir="${HOME}/.claude/projects/${proj_key}"

  [[ -d "$proj_dir" ]] || return 1

  local -a results=()
  local meta

  for f in "$proj_dir"/*.jsonl; do
    [[ -f "$f" ]] || continue
    meta=$(_ch_session_meta "$f")
    [[ -z "$meta" ]] && continue
    results+=("$meta")
  done

  # Sort by date descending (newest first); "unknown" dates sink to the bottom
  printf '%s\n' "${results[@]}" | awk -F'\t' '$2 != "unknown"' | sort -t$'\t' -k2 -r
  printf '%s\n' "${results[@]}" | awk -F'\t' '$2 == "unknown"'
}

# Opens fzf to pick a project from ~/.claude/projects/.
# Prints the selected project key to stdout.
_ch_pick_project() {
  local projects_dir="${HOME}/.claude/projects"
  local -a keys=()
  local -a labels=()
  local key count label

  local -a active_keys=() active_labels=() gone_keys=() gone_labels=()
  local home_enc
  home_enc=$(_ch_encode_project_key "$HOME")

  for d in "$projects_dir"/*(N/); do
    [[ -d "$d" ]] || continue
    key=$(basename "$d")
    # Use array count — avoids print-with-no-args blank-line bug and wrong glob level
    local -a _ch_files=("${d}/"*.jsonl(N))
    count=${#_ch_files[@]}
    [[ "$count" -gt 0 ]] || continue
    label=$(_ch_decode_project_key "$key")
    if [[ -n "$label" ]]; then
      active_keys+=("$key")
      active_labels+=("${label}  (${count} sessions)")
    else
      # Path not on disk — strip home prefix from encoded key for a cleaner label
      local stripped="${key#${home_enc}}"
      [[ "$stripped" == "$key" ]] && stripped="${key#-}"
      gone_keys+=("$key")
      gone_labels+=("(gone) ~${stripped}  (${count} sessions)")
    fi
  done

  keys=("${active_keys[@]}" "${gone_keys[@]}")
  labels=("${active_labels[@]}" "${gone_labels[@]}")

  [[ ${#labels[@]} -eq 0 ]] && { echo "No Claude projects found."; return 1; }

  local chosen
  chosen=$(printf '%s\n' "${labels[@]}" | fzf \
    --prompt="Project > " \
    --height=40% \
    --border=rounded \
    --header="Select a project  (esc to cancel)" \
    --no-multi)

  [[ -z "$chosen" ]] && return 1

  local i
  for (( i=1; i<=${#labels[@]}; i++ )); do
    if [[ "${labels[$i]}" == "$chosen" ]]; then
      echo "${keys[$i]}"
      return 0
    fi
  done
  return 1
}

# Generate fzf preview pane content for one session.
# Arg 1: project_key
# Arg 2: tab-separated line: uuid<TAB>date<TAB>display<TAB>first_msg
_ch_preview() {
  local proj_key="$1"
  local line="$2"

  local uuid date display first_msg
  uuid=$(printf '%s' "$line"     | cut -f1)
  date=$(printf '%s' "$line"     | cut -f2)
  display=$(printf '%s' "$line"  | cut -f3)
  first_msg=$(printf '%s' "$line" | cut -f4)

  local proj_label
  proj_label=$(_ch_decode_project_key "$proj_key")
  [[ -z "$proj_label" ]] && proj_label="$proj_key"

  local file="${HOME}/.claude/projects/${proj_key}/${uuid}.jsonl"
  local msg_count=0
  [[ -f "$file" ]] && msg_count=$(wc -l < "$file" | tr -d ' ')

  local name_source="first message"
  if [[ -f "$file" ]]; then
    if grep -qF '"type":"custom-title"' "$file" 2>/dev/null; then
      name_source="custom title (/rename)"
    elif grep -qF '"slug"' "$file" 2>/dev/null; then
      name_source="auto slug"
    fi
  fi

  printf '\n'
  printf '  Session:    %s\n' "$uuid"
  printf '  Date:       %s\n' "$date"
  printf '  Project:    %s\n' "$proj_label"
  printf '  Lines:      %s\n' "$msg_count"
  printf '  Name from:  %s\n' "$name_source"
  printf '\n'
  printf '  ── First message ──────────────────────────────\n'
  printf '\n'
  printf '  %s\n' "$first_msg"
  printf '\n'
}

# Rename a session by appending a custom-title entry (same format as /rename).
# Args: project_key, session_uuid
_ch_rename_session() {
  local proj_key="$1"
  local uuid="$2"
  local file="${HOME}/.claude/projects/${proj_key}/${uuid}.jsonl"

  [[ -f "$file" ]] || { printf 'Session file not found: %s\n' "$file"; return 1; }

  local current
  current=$(python3 -c "
import sys, json
ct = ''
for line in open('$file', errors='replace'):
    try:
        o = json.loads(line)
        if o.get('type') == 'custom-title' and o.get('customTitle'):
            ct = o['customTitle']
    except: pass
print(ct or 'unnamed')
" 2>/dev/null)

  printf 'New name (current: %s): ' "$current"
  local new_name
  IFS= read -r new_name

  [[ -z "$new_name" ]] && { printf 'Cancelled.\n'; return 1; }

  local entry
  entry=$(python3 -c "
import sys, json
print(json.dumps({'type': 'custom-title', 'customTitle': sys.argv[1], 'sessionId': sys.argv[2]}))
" "$new_name" "$uuid" 2>/dev/null)

  [[ -z "$entry" ]] && { printf 'Failed to create entry.\n'; return 1; }

  printf '%s\n' "$entry" >> "$file"
  printf 'Renamed to: %s\n' "$new_name"
}

# Delete a session JSONL file after confirmation.
# Args: project_key, session_uuid
_ch_delete_session() {
  local proj_key="$1"
  local uuid="$2"
  local file="${HOME}/.claude/projects/${proj_key}/${uuid}.jsonl"

  [[ -f "$file" ]] || { printf 'Session not found: %s\n' "$file"; return 1; }

  printf 'Delete session %s? [y/N] ' "$uuid"
  local confirm
  IFS= read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { printf 'Cancelled.\n'; return 1; }

  rm "$file" && printf 'Deleted.\n'
}

# ── Main entry point ────────────────────────────────────────────────────────────

claude-history() {
  local proj_key="${1:-}"

  # Pick project if not supplied
  if [[ -z "$proj_key" ]]; then
    proj_key=$(_ch_pick_project) || return 0
  fi

  local proj_label
  proj_label=$(_ch_decode_project_key "$proj_key")
  [[ -z "$proj_label" ]] && proj_label="$proj_key"

  # Build session list: uuid<TAB>date<TAB>display<TAB>first_msg
  local sessions
  sessions=$(_ch_list_sessions "$proj_key")

  if [[ -z "$sessions" ]]; then
    printf 'No sessions found for project: %s\n' "$proj_label"
    return 0
  fi

  # Format for fzf left column: "DATE  DISPLAY_NAME<TAB>uuid<TAB>display<TAB>first_msg"
  local fzf_input
  fzf_input=$(printf '%s\n' "$sessions" | awk -F'\t' '{printf "%-12s  %-50s\t%s\t%s\t%s\t%s\n", $2, $3, $1, $3, $4, $2}')

  local _CH_RELOAD
  _CH_RELOAD="source ~/.zsh_functions/claude-history.zsh; _ch_list_sessions '${proj_key}' | awk -F'\t' '{printf \"%-12s  %-50s\t%s\t%s\t%s\t%s\n\", \$2, \$3, \$1, \$3, \$4, \$2}'"

  local selected
  selected=$(printf '%s\n' "$fzf_input" | fzf \
    --prompt="Session > " \
    --height=80% \
    --border=rounded \
    --header="Project: ${proj_label}  │  Enter: resume  ctrl-r: rename  ctrl-d: delete  ctrl-p: switch project" \
    --header-first \
    --delimiter=$'\t' \
    --with-nth=1 \
    --preview="source ~/.zsh_functions/claude-history.zsh; _ch_preview '${proj_key}' \"{2}\t{5}\t{3}\t{4}\"" \
    --preview-window=right:45%:wrap \
    --bind "ctrl-r:execute(source ~/.zsh_functions/claude-history.zsh; uuid=\$(printf '%s' {} | cut -f2); _ch_rename_session '${proj_key}' \"\$uuid\")+reload(${_CH_RELOAD})" \
    --bind "ctrl-d:execute(source ~/.zsh_functions/claude-history.zsh; uuid=\$(printf '%s' {} | cut -f2); _ch_delete_session '${proj_key}' \"\$uuid\")+reload(${_CH_RELOAD})" \
    --bind "ctrl-p:abort" \
    --expect=ctrl-p \
    --no-multi)

  local key line
  key=$(printf '%s\n' "$selected" | head -1)
  line=$(printf '%s\n' "$selected" | tail -1)

  # ctrl-p: switch project
  if [[ "$key" == "ctrl-p" ]]; then
    claude-history
    return
  fi

  [[ -z "$line" ]] && return 0

  # Enter: resume the selected session
  local uuid
  uuid=$(printf '%s' "$line" | cut -f2)
  [[ -z "$uuid" ]] && return 0

  printf 'Resuming session: %s\n' "$uuid"
  claude --resume "$uuid"
}
