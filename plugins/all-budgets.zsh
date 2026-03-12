# all-budgets.zsh
# Usage: all-budgets — runs all budget plugins in sequence

all-budgets() {
	local bold='\033[1m'
	local reset='\033[0m'
	local dim='\033[2m'
	local white='\033[1;37m'
	local blue='\033[0;34m'

	_budget_divider() {
		echo -e "${dim}────────────────────────────────────────${reset}"
	}

	budget
	_budget_divider
	copilot-budget
	_budget_divider
	cursor-budget
}
