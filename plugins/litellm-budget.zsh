# litellm-budget.zsh
# Usage: budget  (or: litellm-budget)

budget() {
	local raw
	raw=$(curl -s -X 'GET' 'https://uai-litellm.internal.unity.com/key/info' \
		-H 'accept: application/json' \
		-H "x-litellm-api-key: $ANTHROPIC_AUTH_TOKEN")

	if [[ -z "$raw" ]]; then
		echo "Error: no response from LiteLLM API."
		return 1
	fi

	local bold='\033[1m'
	local reset='\033[0m'
	local green='\033[0;32m'
	local yellow='\033[0;33m'
	local red='\033[0;31m'
	local dim='\033[2m'
	local white='\033[1;37m'

	# Parse values
	local spend budget remaining reset_at pct_used pct_remaining
	spend=$(echo "$raw"     | jq -r '.info.spend')
	budget=$(echo "$raw"    | jq -r '.info.max_budget')
	remaining=$(echo "$raw" | jq -r '.info.max_budget - .info.spend')
	reset_at=$(echo "$raw"  | jq -r '.info.budget_reset_at')
	pct_used=$(echo "$raw"  | jq -r '(.info.spend / .info.max_budget * 100) | round')
	pct_remaining=$(echo "$raw" | jq -r '((.info.max_budget - .info.spend) / .info.max_budget * 100) | round')

	# Format numbers to 2 decimal places
	spend_fmt=$(printf "%.2f" "$spend")
	budget_fmt=$(printf "%.2f" "$budget")
	remaining_fmt=$(printf "%.2f" "$remaining")

	# Format reset date as "Apr 1, 2026 (in N days)"
	# macOS date requires %z without colon — strip it from +00:00 → +0000
	local reset_clean reset_fmt days_left reset_epoch
	reset_clean=$(echo "$reset_at" | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/')
	reset_fmt=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$reset_clean" "+%b %-d, %Y" 2>/dev/null || echo "$reset_at")
	reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$reset_clean" "+%s" 2>/dev/null || echo "0")
	days_left=$(( (reset_epoch - $(date "+%s")) / 86400 ))

	# Color based on remaining %
	local value_color
	if [[ "$pct_remaining" -le 10 ]]; then
		value_color="${red}"
	elif [[ "$pct_remaining" -le 25 ]]; then
		value_color="${yellow}"
	else
		value_color="${green}"
	fi

	# Progress bar (30 chars wide)
	local bar_width=30
	local filled=$(( pct_used * bar_width / 100 ))
	local empty=$(( bar_width - filled ))
	local bar=""
	local i=0
	while (( i < filled )); do bar+="█"; (( i++ )); done
	i=0
	while (( i < empty  )); do bar+="░"; (( i++ )); done

	# Output
	echo ""
	echo -e "${bold}${white}LiteLLM Budget${reset}"
	echo ""
	echo -e "\t${dim}spend:     ${reset}${white}\$${spend_fmt}${reset} ${dim}/ \$${budget_fmt}${reset}"
	echo -e "\t${dim}remaining: ${reset}${value_color}${bold}\$${remaining_fmt}${reset} ${dim}(${pct_remaining}% left)${reset}"
	echo -e "\t${dim}reset:     ${reset}${white}${reset_fmt}${reset} ${dim}(in ${days_left} days)${reset}"
	echo ""
	echo -e "\t${value_color}${bar}${reset} ${dim}${pct_used}% used${reset}"
	echo ""
}

alias litellm-budget='budget'
