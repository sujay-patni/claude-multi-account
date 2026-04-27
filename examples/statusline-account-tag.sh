#!/bin/bash
# Example statusline that shows which overlay the current Claude Code session
# is running under. Drop-in replacement for ~/.claude/statusline-command.sh
# (or merge the relevant block into your existing statusline script).
#
# To use:
#   1. Copy this file to ~/.claude/statusline-command.sh and chmod +x it.
#   2. Reference it from ~/.claude/settings.json:
#        "statusLine": { "type": "command", "command": "~/.claude/statusline-command.sh" }
#
# It prints: <dir> (<branch>) [<model>] [<account>] [<context bar> N%]
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // .model // empty')
dir=$(basename "$cwd")
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

# Derive the account label from the overlay name (~/.claude-<name>).
# Falls back to empty if running without an overlay (plain `claude`).
account=""
acct_color=""
case "$CLAUDE_CONFIG_DIR" in
  "$HOME/.claude-"*)
    account="${CLAUDE_CONFIG_DIR##*/.claude-}"
    # Pick a color from the name so different accounts visibly differ.
    case "$account" in
      personal|sub)  acct_color="\033[1;36m" ;;  # cyan
      work|enterprise) acct_color="\033[1;35m" ;;  # magenta
      *)             acct_color="\033[1;33m" ;;  # yellow for everything else
    esac
    ;;
esac

RESET="\033[0m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"

printf "${BLUE}%s${RESET}" "$dir"
[ -n "$branch" ] && printf " ${GREEN}(%s)${RESET}" "$branch"
[ -n "$model" ]  && printf " ${YELLOW}[%s]${RESET}" "$model"
[ -n "$account" ] && printf " ${acct_color}[%s]${RESET}" "$account"

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  bar_width=10
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar=""
  for _ in $(seq 1 $filled); do bar="${bar}█"; done
  for _ in $(seq 1 $empty);  do bar="${bar}░"; done
  printf " ${CYAN}[%s] %d%%${RESET}" "$bar" "$used_int"
fi
