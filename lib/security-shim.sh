#!/bin/sh
# Shim that intercepts Claude Code's calls to the macOS `security` binary.
#
# Claude Code stores OAuth credentials in the macOS Keychain by default, which
# is system-wide — so two installs share one set of credentials and you can
# only be signed in to one account at a time.
#
# By prepending an overlay's bin/ to PATH and dropping this shim there, every
# `security` invocation Claude makes is intercepted. Claude then falls back to
# writing/reading credentials from $CLAUDE_CONFIG_DIR/.credentials.json, which
# is per-overlay — giving each overlay its own independent OAuth.
#
# Why `exit 44` and not `exit 1`:
#   Real `security find-generic-password` returns exit 44 ("item not found")
#   when a keychain entry is absent. Claude Code 2.1.x distinguishes this from a
#   generic keychain *error*:
#     - exit 44  -> "keychain works, entry just doesn't exist" -> falls back to
#                   the plaintext .credentials.json (what we want).
#     - any other non-zero (e.g. 1) -> "keychain ERRORED" -> Claude returns an
#                   internal error sentinel and SUPPRESSES the plaintext
#                   fallback, so login loops forever.
#   Earlier Claude versions treated any failure as "empty" and fell back, so
#   `exit 1` used to work; it no longer does. Mimic "item not found" instead.
#
# Active only inside a `claude-as <account>` invocation; never affects normal
# `security` usage outside that wrapped shell.
exit 44
