#!/usr/bin/env bash
# install.sh — wire claude-multi-account into your shell.
#
# What this does:
#   1. Verifies you're on macOS (the security shim is macOS-specific).
#   2. Adds a `claude-as <account>` shell function to ~/.zshrc and/or ~/.bashrc.
#   3. Tells you how to add overlays with `claude-account add <name>`.
#
# Idempotent: marker comments delimit the injected block, so re-running this
# script replaces the block instead of appending duplicates.
#
# This script does NOT create overlays and does NOT touch ~/.claude/ itself.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$REPO_ROOT/bin"
MARKER_BEGIN="# >>> claude-multi-account >>>"
MARKER_END="# <<< claude-multi-account <<<"

die() { printf 'install: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

[ "$(uname)" = "Darwin" ] || die "macOS only. The security-binary shim has no effect on Linux/WSL (those use libsecret/gnome-keyring)."

[ -x "$BIN_DIR/claude-account" ] || die "missing $BIN_DIR/claude-account (broken checkout?)"
chmod +x "$BIN_DIR/claude-account" "$REPO_ROOT/lib/security-shim.sh" 2>/dev/null || true

if ! command -v claude >/dev/null 2>&1; then
  cat >&2 <<EOF
WARNING: 'claude' command not found on PATH. claude-multi-account drives
Claude Code, so install it first: https://docs.claude.com/en/docs/claude-code
Continuing anyway — you can install Claude Code later.

EOF
fi

build_block() {
  cat <<EOF
$MARKER_BEGIN
# Claude Code multi-account launcher. Repo: $REPO_ROOT
# Usage: claude-as <account> [claude args...]
# Manage overlays: claude-account add|remove|list
export PATH="$BIN_DIR:\$PATH"
claude-as() {
  if [ -z "\${1:-}" ]; then
    echo "Usage: claude-as <account> [claude args...]" >&2
    echo "List accounts: claude-account list" >&2
    return 1
  fi
  local acct="\$1"; shift
  local overlay="\$HOME/.claude-\$acct"
  if [ ! -d "\$overlay" ]; then
    echo "claude-as: no overlay at \$overlay. Create it with: claude-account add \$acct" >&2
    return 1
  fi
  PATH="\$overlay/bin:\$PATH" CLAUDE_CONFIG_DIR="\$overlay" command claude "\$@"
}
$MARKER_END
EOF
}

inject() {
  local rc="$1"
  [ -e "$rc" ] || touch "$rc"

  if grep -qF "$MARKER_BEGIN" "$rc"; then
    info "Updating existing block in $rc"
    # Strip the old block, then append a fresh one. Use a tmp file for portability.
    local tmp; tmp="$(mktemp)"
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip   {print}
    ' "$rc" > "$tmp"
    mv "$tmp" "$rc"
  else
    info "Adding block to $rc"
  fi

  printf '\n%s\n' "$(build_block)" >> "$rc"
}

# Inject into whichever rc files exist; create ~/.zshrc if neither exists,
# since macOS defaults to zsh.
RCS_TOUCHED=()
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -e "$rc" ]; then
    inject "$rc"
    RCS_TOUCHED+=("$rc")
  fi
done

if [ ${#RCS_TOUCHED[@]} -eq 0 ]; then
  inject "$HOME/.zshrc"
  RCS_TOUCHED+=("$HOME/.zshrc")
fi

cat <<EOF

Installed. Touched: ${RCS_TOUCHED[*]}

Next steps:
  1. Open a new terminal (or run:  source ${RCS_TOUCHED[0]})
  2. Create your overlays, e.g.:
       claude-account add personal
       claude-account add work
  3. Launch:
       claude-as personal     # logs into one OAuth account
       claude-as work         # logs into another, fully independent

Each overlay holds its own .credentials.json — see README.md for the trade-offs.
EOF
