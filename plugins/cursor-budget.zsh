# cursor-budget.zsh
# Usage: cursor-budget

cursor-budget() {
	local db="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"

	if [[ ! -f "$db" ]]; then
		echo "Error: Cursor not installed or globalStorage not found."
		return 1
	fi

	local token email plan
	token=$(sqlite3 "$db" "SELECT value FROM ItemTable WHERE key='cursorAuth/accessToken'" 2>/dev/null)
	email=$(sqlite3 "$db" "SELECT value FROM ItemTable WHERE key='cursorAuth/cachedEmail'" 2>/dev/null)
	plan=$(sqlite3  "$db" "SELECT value FROM ItemTable WHERE key='cursorAuth/stripeMembershipType'" 2>/dev/null)

	if [[ -z "$token" ]]; then
		echo "Error: No Cursor auth token found. Please log in to Cursor."
		return 1
	fi

	local raw
	raw=$(curl -s "https://api2.cursor.sh/auth/usage" \
		-H "Authorization: Bearer $token")

	if [[ -z "$raw" ]] || echo "$raw" | jq -e '.message' &>/dev/null; then
		echo "Error: $(echo "$raw" | jq -r '.message // "no response from Cursor API"')"
		return 1
	fi

	local bold='\033[1m'
	local reset='\033[0m'
	local green='\033[0;32m'
	local yellow='\033[0;33m'
	local red='\033[0;31m'
	local dim='\033[2m'
	local white='\033[1;37m'

	# Parse month start and compute days remaining
	local start_of_month reset_epoch reset_fmt days_left now_epoch month_days
	start_of_month=$(echo "$raw" | jq -r '.startOfMonth')
	start_clean=$(echo "$start_of_month" | sed 's/\..*//' | sed 's/T.*//')
	# Next month = reset date
	local year month
	year=$(echo "$start_clean" | cut -d- -f1)
	month=$(echo "$start_clean" | cut -d- -f2)
	next_month=$(( 10#$month + 1 ))
	next_year=$year
	if (( next_month > 12 )); then next_month=1; next_year=$(( year + 1 )); fi
	reset_fmt=$(printf "%s-%02d-01T00:00:00" "$next_year" "$next_month")
	reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$reset_fmt" "+%s" 2>/dev/null || echo "0")
	reset_display=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$reset_fmt" "+%b %-d, %Y" 2>/dev/null || echo "$reset_fmt")
	now_epoch=$(date "+%s")
	days_left=$(( (reset_epoch - now_epoch) / 86400 ))

	echo ""
	echo -e "${bold}${white}Cursor Budget${reset} ${dim}(${plan} · ${email})${reset}"
	echo ""

	# Render each model's usage
	echo "$raw" | jq -r 'to_entries[] | select(.key != "startOfMonth") | "\(.key) \(.value.numRequests) \(.value.maxRequestUsage // "unlimited")"' | \
	while IFS=' ' read -r model used quota; do
		local label="${model}"

		if [[ "$quota" == "unlimited" ]]; then
			echo -e "\t${dim}${label}:${reset} ${white}${bold}${used}${reset} ${dim}requests used (unlimited)${reset}"
			continue
		fi

		local pct_used pct_remaining value_color
		pct_used=$(( used * 100 / quota ))
		pct_remaining=$(( 100 - pct_used ))

		if [[ "$pct_remaining" -le 10 ]]; then
			value_color="${red}"
		elif [[ "$pct_remaining" -le 25 ]]; then
			value_color="${yellow}"
		else
			value_color="${green}"
		fi

		local remaining=$(( quota - used ))

		# Progress bar (30 chars wide)
		local bar_width=30
		local filled=$(( pct_used * bar_width / 100 ))
		local empty=$(( bar_width - filled ))
		local bar="" i=0
		while (( i < filled )); do bar+="█"; (( i++ )); done
		i=0
		while (( i < empty )); do bar+="░"; (( i++ )); done

		echo -e "\t${dim}${label}:${reset} ${value_color}${bold}${remaining}${reset}${dim} / ${quota} remaining (${pct_remaining}%)${reset}"
		echo -e "\t$(printf '%*s' $(( ${#label} + 1 )) '') ${value_color}${bar}${reset} ${dim}${pct_used}% used${reset}"
	done

	echo ""
	echo -e "\t${dim}resets:  ${reset}${white}${reset_display}${reset} ${dim}(in ${days_left} days)${reset}"
	echo ""
}
