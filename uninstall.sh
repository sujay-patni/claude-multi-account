#!/usr/bin/env bash
# uninstall.sh — remove the claude-multi-account block from your shell rc files.
#
# Does NOT touch ~/.claude-* overlays. They contain OAuth credentials; remove
# them deliberately with:  claude-account remove <name>
set -euo pipefail

MARKER_BEGIN="# >>> claude-multi-account >>>"
MARKER_END="# <<< claude-multi-account <<<"

info() { printf '==> %s\n' "$*"; }

strip_block() {
  local rc="$1"
  [ -e "$rc" ] || return 0
  if ! grep -qF "$MARKER_BEGIN" "$rc"; then
    info "No block in $rc — skipping."
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    !skip   {print}
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  info "Removed block from $rc"
}

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  strip_block "$rc"
done

# Show remaining overlays so the user knows what's still on disk.
shopt -s nullglob
overlays=("$HOME"/.claude-*/)
shopt -u nullglob

cat <<EOF

Done. The 'claude-as' function is gone from your shell rc.

Overlays preserved (each contains an OAuth credential file):
EOF
if [ ${#overlays[@]} -eq 0 ]; then
  echo "  (none)"
else
  for o in "${overlays[@]}"; do echo "  $o"; done
  cat <<EOF

To delete an overlay and its credentials, run (before removing this checkout):
  ./bin/claude-account remove <name>
EOF
fi
