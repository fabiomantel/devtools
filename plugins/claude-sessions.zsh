# claude-sessions.zsh
# Usage: claude-sessions

# jq script written once at load time to avoid shell-escaping issues with !=
_CLAUDE_SESSIONS_JQ=$(cat << 'EOF'
map(.message.usage | select(. != null)) | {
  input:       (map(.input_tokens                    // 0) | add),
  output:      (map(.output_tokens                   // 0) | add),
  cache_read:  (map(.cache_read_input_tokens         // 0) | add),
  cache_write: (map(.cache_creation_input_tokens     // 0) | add)
}
EOF
)

_CLAUDE_SLUG_JQ=$(cat << 'EOF'
last(.[] | select(.slug != null) | .slug) // ""
EOF
)

claude-sessions() {
	{ set +x; } 2>/dev/null

	local bold='\033[1m'
	local reset='\033[0m'
	local green='\033[0;32m'
	local yellow='\033[0;33m'
	local dim='\033[2m'
	local white='\033[1;37m'
	local cyan='\033[0;36m'

	# Match only the actual claude CLI binary
	local procs
	procs=$(ps aux | awk 'NR>1 && ($11 == "claude" || $11 ~ /\/claude$/) {print}')

	if [[ -z "$procs" ]]; then
		echo -e "\n${dim}No active Claude Code sessions.${reset}\n"
		return 0
	fi

	local session_count=0
	local total_cost=0

	echo -e "\n${bold}${white}Claude Sessions${reset}\n"

	while IFS= read -r proc_line; do
		local proc_pid proc_cpu proc_mem proc_elapsed proc_flags proc_workdir_abs proc_workdir

		proc_pid=$(echo "$proc_line"  | awk '{print $2}')
		proc_cpu=$(echo "$proc_line"  | awk '{print $3}')
		proc_mem=$(echo "$proc_line"  | awk '{print $4}')
		local proc_full_cmd
		proc_full_cmd=$(echo "$proc_line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}' | xargs)
		# Show only flags, not the binary name
		proc_flags=$(echo "$proc_full_cmd" | sed 's/^claude[^ ]* *//' | xargs)
		[[ -z "$proc_flags" ]] && proc_flags="${dim}(no flags)${reset}"

		proc_workdir_abs=$(lsof -p "$proc_pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | sed 's/^n//')
		proc_workdir="${proc_workdir_abs:-unknown}"
		proc_workdir="${proc_workdir/#$HOME/~}"
		proc_elapsed=$(ps -p "$proc_pid" -o etime= 2>/dev/null | xargs)

		# ── Session slug + cost from ~/.claude/projects/ ─────────
		local slug="" cost="0" out_k="0" cr_m="0" cw_k="0" has_cost=false

		if [[ -n "$proc_workdir_abs" ]]; then
			local proj_key proj_dir session_file
			proj_key=$(echo "$proc_workdir_abs" | tr '/.' '-')
			proj_dir="${HOME}/.claude/projects/${proj_key}"
			session_file=$(ls -t "${proj_dir}"/*.jsonl 2>/dev/null | head -1 2>/dev/null)

			if [[ -n "$session_file" ]]; then
				# Session slug
				slug=$(echo "$_CLAUDE_SLUG_JQ" | jq -rsf /dev/stdin "$session_file" 2>/dev/null)

				# Token usage + cost
				local tokens
				tokens=$(echo "$_CLAUDE_SESSIONS_JQ" | jq -rsf /dev/stdin "$session_file" 2>/dev/null)
				if [[ -n "$tokens" ]]; then
					local inp out cr cw
					inp=$(echo "$tokens" | jq '.input')
					out=$(echo "$tokens" | jq '.output')
					cr=$(echo "$tokens"  | jq '.cache_read')
					cw=$(echo "$tokens"  | jq '.cache_write')

					# Pricing: claude-sonnet-4-6
					# Input $3/1M  Output $15/1M  Cache-read $0.30/1M  Cache-write $3.75/1M
					cost=$(echo "$inp $out $cr $cw" | awk '{
						printf "%.2f", ($1 * 3 + $2 * 15 + $3 * 0.30 + $4 * 3.75) / 1000000
					}')
					out_k=$(echo "$out" | awk '{printf "%.1fk", $1/1000}')
					cr_m=$(echo "$cr"   | awk '{printf "%.1fM", $1/1000000}')
					cw_k=$(echo "$cw"   | awk '{printf "%.1fk", $1/1000}')
					has_cost=true
					total_cost=$(echo "$total_cost $cost" | awk '{printf "%.2f", $1 + $2}')
				fi
			fi
		fi

		(( session_count++ ))

		# Header — use slug if available, else PID
		local header="PID ${proc_pid}"
		[[ -n "$slug" ]] && header="${slug}  ${dim}(PID ${proc_pid})${reset}"

		echo -e "${bold}${cyan}┌─ ${header}${reset}"
		echo -e "${cyan}│${reset}\t${dim}flags:    ${reset}${white}${proc_flags}${reset}"
		echo -e "${cyan}│${reset}\t${dim}workdir:  ${reset}${proc_workdir}"
		echo -e "${cyan}│${reset}\t${dim}running:  ${reset}${proc_elapsed}"
		echo -e "${cyan}│${reset}\t${dim}cpu/mem:  ${reset}${green}${proc_cpu}%${reset} CPU  ${yellow}${proc_mem}%${reset} MEM"
		if $has_cost; then
			echo -e "${cyan}│${reset}\t${dim}cost:     ${reset}~${yellow}\$${cost}${reset}  ${dim}out ${out_k}  cache-read ${cr_m}  cache-write ${cw_k}${reset}"
		fi
		echo -e "${bold}${cyan}└────────────────────────────────────────────────────${reset}"
		echo ""
	done <<< "$procs"

	# Total across all sessions
	if [[ "$session_count" -gt 1 ]]; then
		echo -e "${dim}${session_count} sessions  total cost: ${reset}~${yellow}\$${total_cost}${reset}\n"
	fi
}
