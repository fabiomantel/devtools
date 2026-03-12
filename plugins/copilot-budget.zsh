# copilot-budget.zsh
# Usage: copilot-budget

copilot-budget() {
	local raw
	raw=$(curl -s "https://api.github.com/copilot_internal/user" \
		-H "Authorization: Bearer $(gh auth token)" \
		-H "Accept: application/json")

	if [[ -z "$raw" ]]; then
		echo "Error: no response from GitHub Copilot API."
		return 1
	fi

	local error
	error=$(echo "$raw" | jq -r '.message // empty')
	if [[ -n "$error" ]]; then
		echo "Error: $error"
		return 1
	fi

	local bold='\033[1m'
	local reset='\033[0m'
	local green='\033[0;32m'
	local yellow='\033[0;33m'
	local red='\033[0;31m'
	local dim='\033[2m'
	local white='\033[1;37m'

	local plan reset_date days_left reset_epoch
	plan=$(echo "$raw" | jq -r '.copilot_plan')
	reset_date=$(echo "$raw" | jq -r '.quota_reset_date_utc')
	reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "$reset_date" "+%s" 2>/dev/null || echo "0")
	days_left=$(( (reset_epoch - $(date "+%s")) / 86400 ))
	reset_fmt=$(date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "$reset_date" "+%b %-d, %Y" 2>/dev/null || echo "$reset_date")

	echo ""
	echo -e "${bold}${white}GitHub Copilot Budget${reset} ${dim}(${plan})${reset}"
	echo ""

	# Iterate over quota snapshots
	for quota_id in premium_interactions chat completions; do
		local entitlement unlimited remaining pct_remaining pct_used label
		entitlement=$(echo "$raw" | jq -r ".quota_snapshots.${quota_id}.entitlement")
		unlimited=$(echo "$raw"   | jq -r ".quota_snapshots.${quota_id}.unlimited")
		remaining=$(echo "$raw"   | jq -r ".quota_snapshots.${quota_id}.remaining")
		pct_remaining=$(echo "$raw" | jq -r ".quota_snapshots.${quota_id}.percent_remaining | round")

		case "$quota_id" in
			premium_interactions) label="Premium Requests" ;;
			chat)                 label="Chat            " ;;
			completions)          label="Completions     " ;;
		esac

		if [[ "$unlimited" == "true" ]]; then
			echo -e "\t${dim}${label}:${reset} ${green}${bold}unlimited${reset}"
			continue
		fi

		pct_used=$(( 100 - pct_remaining ))

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
		local bar="" i=0
		while (( i < filled )); do bar+="█"; (( i++ )); done
		i=0
		while (( i < empty  )); do bar+="░"; (( i++ )); done

		echo -e "\t${dim}${label}:${reset} ${value_color}${bold}${remaining}${reset}${dim} / ${entitlement} remaining (${pct_remaining}%)${reset}"
		echo -e "\t               ${value_color}${bar}${reset} ${dim}${pct_used}% used${reset}"
	done

	echo ""
	echo -e "\t${dim}resets:  ${reset}${white}${reset_fmt}${reset} ${dim}(in ${days_left} days)${reset}"
	echo ""
}
