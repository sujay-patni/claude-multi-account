#!/bin/sh
# Shim that intercepts Claude Code's calls to the macOS `security` binary.
#
# Claude Code stores OAuth credentials in the macOS Keychain by default, which
# is system-wide — so two installs share one set of credentials and you can
# only be signed in to one account at a time.
#
# By prepending an overlay's bin/ to PATH and dropping this shim there, every
# `security` invocation Claude makes returns failure. Claude then falls back
# to writing/reading credentials from $CLAUDE_CONFIG_DIR/.credentials.json,
# which is per-overlay — giving each overlay its own independent OAuth.
#
# Active only inside a `claude-as <account>` invocation; never affects normal
# `security` usage outside that wrapped shell.
exit 1
