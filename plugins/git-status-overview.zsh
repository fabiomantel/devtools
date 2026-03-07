# git-status-overview.zsh
# Usage: gst

_GST_WT_COLORS=('\033[0;35m' '\033[0;36m' '\033[0;33m' '\033[38;5;208m' '\033[38;5;141m' '\033[38;5;75m')

_gst_print_worktree() {
	local dir="$1"
	local label="$2"
	local accent="$3"
	local is_main="${4:-false}"

	local bold='\033[1m'
	local reset='\033[0m'
	local green='\033[0;32m'
	local yellow='\033[0;33m'
	local red='\033[0;31m'
	local dim='\033[2m'
	local white='\033[0;37m'
	local orange='\033[38;5;208m'

	local branch
	branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
	[[ -z "$branch" ]] && return

	local short_dir="${dir/#$HOME/~}"

	# ── Auto-detect base branch ──────────────────────────────────
	local base_branch
	base_branch=$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
	[[ -z "$base_branch" ]] && base_branch="main"

	# ── Fetch PR state early so it can gate other sections ───────
	local pr_info pr_state=""
	if [[ "$is_main" != "true" ]]; then
		pr_info=$(gh pr view "$branch" --json number,title,state,url,reviewDecision,statusCheckRollup 2>/dev/null)
		[[ -n "$pr_info" ]] && pr_state=$(echo "$pr_info" | jq -r '.state')
	fi

	# ── Box top ─────────────────────────────────────────────────
	echo -e "${accent}${bold}┌─ ${label}: ${branch}${reset}"
	echo -e "${accent}│${reset}\t${dim}${short_dir}${reset}"

	# ── Last commit (single call) ────────────────────────────────
	local commit_info commit_hash commit_msg commit_time commit_author
	commit_info=$(git -C "$dir" log -1 --format=$'%h\x1f%s\x1f%cr\x1f%an' 2>/dev/null)
	IFS=$'\x1f' read -r commit_hash commit_msg commit_time commit_author <<< "$commit_info"
	echo -e "${accent}│${reset}\t${dim}last:      ${reset}${white}${commit_hash}${reset} ${commit_msg} ${dim}by ${commit_author} (${commit_time})${reset}"

	# ── Branch age + base staleness (skip on MAIN and MERGED PRs) ──
	if [[ "$is_main" != "true" && "$pr_state" != "MERGED" ]]; then
		local branch_age
		branch_age=$(git -C "$dir" log "${base_branch}..HEAD" --format="%cr" 2>/dev/null | tail -1)
		[[ -n "$branch_age" ]] && echo -e "${accent}│${reset}\t${dim}age:       ${reset}branch started ${branch_age}"

		local ahead_main stale_by merge_base base_info=""
		ahead_main=$(git -C "$dir" rev-list "${base_branch}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
		merge_base=$(git -C "$dir" merge-base HEAD "${base_branch}" 2>/dev/null)
		if [[ -n "$merge_base" ]]; then
			stale_by=$(git -C "$dir" rev-list "${merge_base}..${base_branch}" 2>/dev/null | wc -l | tr -d ' ')
		fi

		[[ "$ahead_main" -gt 0 ]] && base_info+="${white}+${ahead_main} commits vs ${base_branch}${reset}"
		if [[ -n "$stale_by" && "$stale_by" -gt 0 ]]; then
			[[ -n "$base_info" ]] && base_info+="  "
			base_info+="${orange}⚠ based ${stale_by} commits behind ${base_branch}${reset}"
		elif [[ -n "$stale_by" && "$stale_by" -eq 0 && "$ahead_main" -gt 0 ]]; then
			[[ -n "$base_info" ]] && base_info+="  "
			base_info+="${green}base up to date${reset}"
		fi
		[[ -n "$base_info" ]] && echo -e "${accent}│${reset}\t${dim}base:      ${reset}${base_info}"
	fi

	# ── Sync with remote ────────────────────────────────────────
	local remote_branch sync_info=""
	remote_branch=$(git -C "$dir" rev-parse --abbrev-ref "@{u}" 2>/dev/null)
	if [[ -n "$remote_branch" ]]; then
		local ahead behind
		ahead=$(git -C "$dir" rev-list "@{u}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
		behind=$(git -C "$dir" rev-list "HEAD..@{u}" 2>/dev/null | wc -l | tr -d ' ')
		[[ "$ahead" -gt 0 ]]  && sync_info+="${accent}↑ ${ahead} to push${reset}"
		[[ "$behind" -gt 0 ]] && sync_info+=" ${red}↓ ${behind} to pull${reset}"
		[[ "$ahead" -eq 0 && "$behind" -eq 0 ]] && sync_info="${dim}≡ in sync${reset}"
	else
		sync_info="${bold}${orange}⚠ never pushed — no remote${reset}"
	fi
	echo -e "${accent}│${reset}\t${dim}sync:      ${reset}${sync_info}"

	# ── Stash (branch-specific) ──────────────────────────────────
	local stash_count
	stash_count=$(git -C "$dir" stash list 2>/dev/null | grep -c "WIP on ${branch}:\|On ${branch}:" || true)
	if [[ "$stash_count" -gt 0 ]]; then
		echo -e "${accent}│${reset}\t${dim}stash:     ${reset}${yellow}${stash_count} stashed $([ "$stash_count" -eq 1 ] && echo entry || echo entries)${reset}"
	fi

	# ── PR status (skip on MAIN) ─────────────────────────────────
	if [[ "$is_main" != "true" && -n "$pr_info" ]]; then
		local pr_num pr_url pr_title pr_color pr_review
		pr_num=$(echo "$pr_info" | jq -r '.number')
		pr_url=$(echo "$pr_info" | jq -r '.url')
		pr_title=$(echo "$pr_info" | jq -r '.title')
		pr_review=$(echo "$pr_info" | jq -r '.reviewDecision // ""')

		case "$pr_state" in
			OPEN)   pr_color="${green}" ;;
			MERGED) pr_color="${dim}" ;;
			CLOSED) pr_color="${red}" ;;
			*)      pr_color="${dim}" ;;
		esac
		echo -e "${accent}│${reset}\t${dim}pr:        ${reset}${pr_color}#${pr_num} [${pr_state}]${reset} ${pr_title}"
		echo -e "${accent}│${reset}\t\t${dim}${pr_url}${reset}"

		if [[ "$pr_state" == "MERGED" ]]; then
			echo -e "${accent}│${reset}\t\t${orange}⚠ PR merged — safe to remove this worktree${reset}"
		else
			# Review and CI only relevant for open/closed PRs
			local review_icon
			case "$pr_review" in
				APPROVED)          review_icon="${green}✔ approved${reset}" ;;
				CHANGES_REQUESTED) review_icon="${red}✘ changes requested${reset}" ;;
				REVIEW_REQUIRED)   review_icon="${yellow}⏳ review required${reset}" ;;
				*)                 review_icon="${dim}no reviews yet${reset}" ;;
			esac
			echo -e "${accent}│${reset}\t\t${dim}review:    ${reset}${review_icon}"

			local total_checks failed_checks pending_checks
			total_checks=$(echo "$pr_info" | jq '.statusCheckRollup | length' 2>/dev/null)
			failed_checks=$(echo "$pr_info" | jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")] | length' 2>/dev/null)
			pending_checks=$(echo "$pr_info" | jq '[.statusCheckRollup[] | select(.conclusion == null or .conclusion == "")] | length' 2>/dev/null)

			if [[ -n "$total_checks" && "$total_checks" -gt 0 ]]; then
				local ci_icon
				if [[ "$failed_checks" -gt 0 ]]; then
					ci_icon="${red}✘ ${failed_checks}/${total_checks} checks failing${reset}"
				elif [[ "$pending_checks" -gt 0 ]]; then
					ci_icon="${yellow}⏳ ${pending_checks}/${total_checks} checks pending${reset}"
				else
					ci_icon="${green}✔ all ${total_checks} checks passed${reset}"
				fi
				echo -e "${accent}│${reset}\t\t${dim}ci:        ${reset}${ci_icon}"
			fi
		fi
	fi

	# ── Working tree changes ─────────────────────────────────────
	# Compute all three file lists first, then derive dirty from real content
	local staged_files unstaged_files untracked_files

	staged_files=$(git -C "$dir" diff --cached --name-status 2>/dev/null)

	unstaged_files=$(git -C "$dir" diff --name-status 2>/dev/null)

	untracked_files=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null \
		| grep -v -E '^(node_modules|\.DS_Store|\.idea|\.vscode|dist|build|coverage|\.cache|__pycache__)(/|$)' \
		| grep -v -E '\.(log|tmp|swp|swo)$')

	if [[ -n "$staged_files" || -n "$unstaged_files" || -n "$untracked_files" ]]; then
		echo -e "${accent}│${reset}\t${dim}status:    ${reset}${yellow}✎ dirty${reset}"

		if [[ -n "$staged_files" ]]; then
			local staged_count
			staged_count=$(echo "$staged_files" | grep -c .)
			echo -e "${accent}│${reset}\t${dim}staged:    ${reset}${staged_count} $([ "$staged_count" -eq 1 ] && echo file || echo files)"
			while IFS= read -r line; do
				local sc fn
				sc="${line:0:1}"; fn="${line:2}"
				case "$sc" in
					A) echo -e "${accent}│${reset}\t\t${green}+ ${fn}${reset}" ;;
					D) echo -e "${accent}│${reset}\t\t${red}- ${fn}${reset}" ;;
					M) echo -e "${accent}│${reset}\t\t${yellow}~ ${fn}${reset}" ;;
					*) echo -e "${accent}│${reset}\t\t${dim}${sc} ${fn}${reset}" ;;
				esac
			done <<< "$staged_files"
		fi

		if [[ -n "$unstaged_files" ]]; then
			local unstaged_count
			unstaged_count=$(echo "$unstaged_files" | grep -c .)
			echo -e "${accent}│${reset}\t${dim}modified:  ${reset}${unstaged_count} $([ "$unstaged_count" -eq 1 ] && echo file || echo files)"
			while IFS= read -r line; do
				local fn="${line:2}"
				echo -e "${accent}│${reset}\t\t${yellow}~ ${fn}${reset}"
			done <<< "$unstaged_files"
		fi

		if [[ -n "$untracked_files" ]]; then
			local untracked_count
			untracked_count=$(echo "$untracked_files" | grep -c .)
			echo -e "${accent}│${reset}\t${dim}untracked: ${reset}${untracked_count} $([ "$untracked_count" -eq 1 ] && echo file || echo files)"
			while IFS= read -r fn; do
				echo -e "${accent}│${reset}\t\t${dim}? ${fn}${reset}"
			done <<< "$untracked_files"
		fi
	else
		echo -e "${accent}│${reset}\t${dim}status:    ${reset}${green}✔ clean${reset}"
	fi

	# ── Box bottom ───────────────────────────────────────────────
	echo -e "${accent}${bold}└────────────────────────────────────────────────────${reset}"
}

gst() {
	local repo_root
	repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
	if [[ -z "$repo_root" ]]; then
		echo "Not inside a git repository."
		return 1
	fi

	local bold='\033[1m'
	local reset='\033[0m'
	local white='\033[1;37m'
	local dim='\033[2m'

	local repo_name
	repo_name=$(basename "$repo_root")

	local wt_list
	wt_list=$(git -C "$repo_root" worktree list --porcelain 2>/dev/null \
		| awk '/^worktree /{print $2}' \
		| tail -n +2)

	local wt_count=0
	[[ -n "$wt_list" ]] && wt_count=$(echo "$wt_list" | grep -c .)

	local summary=""
	if [[ "$wt_count" -eq 0 ]]; then
		summary="${dim}no active worktrees${reset}"
	elif [[ "$wt_count" -eq 1 ]]; then
		summary="${dim}1 active worktree${reset}"
	else
		summary="${dim}${wt_count} active worktrees${reset}"
	fi

	echo -e "\n${bold}${white}${repo_name}${reset}  ${summary}\n"

	_gst_print_worktree "$repo_root" "MAIN" '\033[1;37m' "true"

	if [[ -n "$wt_list" ]]; then
		local idx=1
		while IFS= read -r wt_dir; do
			local color="${_GST_WT_COLORS[$((( idx - 1 ) % ${#_GST_WT_COLORS[@]} + 1))]}"
			echo ""
			_gst_print_worktree "$wt_dir" "Worktree" "$color" "false"
			(( idx++ ))
		done <<< "$wt_list"
	fi

	echo ""
}
