# claude-multi-account

Run multiple Claude Code accounts on the same Mac, each with its own OAuth
login, side by side. Use a personal subscription in one shell and an
enterprise / org account in another — no logout-login dance, no shared
credentials.

> **macOS only.** The mechanism depends on intercepting calls to the macOS
> `security` binary. On Linux/WSL, Claude Code uses libsecret/gnome-keyring
> instead, so this approach has no effect there.

## Why this is needed

Claude Code stores its OAuth token in the macOS Keychain by default. The
Keychain is system-wide, keyed by service name (`Claude Code-credentials`),
so every `claude` invocation on your Mac reads and writes the same one
entry. That means you can only ever be signed in to a single account at a
time — and switching requires logging out and re-authenticating.

The `CLAUDE_CONFIG_DIR` env var lets you point Claude at a different config
directory, but it does **not** change the Keychain service name. So even
with separate config dirs, both invocations still share one credential.

## How it works

For each account you want to use, this tool creates an "overlay" directory
at `~/.claude-<name>/`. The overlay is mostly symlinks back to your real
`~/.claude/` (settings, plugins, history, hooks, skills, statusline, …) so
your configuration stays single-source-of-truth. The handful of files that
must differ per account are kept real inside the overlay:

- `.credentials.json` — the OAuth token for this account
- `bin/security` — a shim
- `.claude.json`, `policy-limits.json`, `sessions/`, etc. — runtime state
  Claude writes itself

The shim is the trick. When you launch Claude through `claude-as <name>`,
the wrapper prepends `~/.claude-<name>/bin` to `PATH` and sets
`CLAUDE_CONFIG_DIR=~/.claude-<name>`. Claude Code calls the `security`
binary to read/write Keychain entries. Because PATH now resolves `security`
to a one-line shim that just `exit 1`s, every Keychain operation fails, and
Claude falls back to its plaintext credentials path:
`$CLAUDE_CONFIG_DIR/.credentials.json`. That file is per-overlay, so each
account keeps its own OAuth token.

The shim is only on PATH inside `claude-as` — it never affects `security`
elsewhere in your shell.

### Trade-off you should know about

OAuth tokens land in `~/.claude-<name>/.credentials.json` in **plaintext**
on disk, instead of being encrypted in the Keychain. That's the cost of
this approach. Make sure your home directory is on an encrypted volume
(FileVault on macOS, which is the default since Big Sur), and don't sync
these directories to cloud storage.

## Install

```bash
git clone https://github.com/<you>/claude-multi-account.git
cd claude-multi-account
./install.sh
```

`install.sh`:
- adds the repo's `bin/` to your `PATH`
- adds a `claude-as <account>` shell function to `~/.zshrc` (and `~/.bashrc`
  if present), wrapped in marker comments so re-running is idempotent
- does **not** touch `~/.claude/` and does **not** create any overlays

Open a new terminal (or `source ~/.zshrc`) so the function and PATH update
take effect.

## Use

Create overlays:

```bash
claude-account add personal
claude-account add work
```

Launch Claude under one of them:

```bash
claude-as personal     # logs into your personal subscription
claude-as work         # logs into your enterprise account
```

The first time you run `claude-as <name>` you'll be taken through the
normal Claude Code OAuth flow. After that, the overlay remembers the login.

You can run both in different terminal tabs at the same time — they don't
collide.

Other commands:

```bash
claude-account list           # show all overlays and whether each is logged in
claude-account remove work    # delete an overlay (prompts; OAuth token is removed)
```

You can name overlays anything (`claude-account add anthropic`,
`claude-account add customer-x`, …) — the wrapper takes whatever you pass.

## Stale Keychain entry (important on existing installs)

If you used Claude Code before installing this, you probably already have a
`Claude Code-credentials` entry in your macOS Keychain. On some Claude Code
versions that entry can win over the per-overlay `.credentials.json` and
both overlays will end up sharing the same login.

`claude-account add` warns you if it detects this. To delete it:

```bash
security delete-generic-password -s "Claude Code-credentials"
```

You'll be re-prompted to log in on the next `claude-as <name>`, which is
exactly what you want — each overlay then captures its own token.

## Uninstall

```bash
./uninstall.sh
```

Removes the shell-rc block. **Does not delete `~/.claude-*` overlays** —
they hold OAuth credentials, so deletion is a deliberate action:

```bash
./bin/claude-account remove personal
./bin/claude-account remove work
```

## Troubleshooting

**Both accounts seem to share the same login.**
Check the macOS Keychain (Keychain Access → search "Claude Code"). If
there's a `Claude Code-credentials` entry, delete it (see section above).

**`claude-as: no overlay at ~/.claude-foo`.**
Run `claude-account add foo` first.

**The shim suddenly stops working.**
The shim relies on Claude Code calling `security` by its bare name, so PATH
resolves to the shim. If a future Claude Code release switches to calling
`/usr/bin/security` with an absolute path, the shim is bypassed and the
Keychain re-asserts. If parallel logins suddenly collapse to one account
after a Claude Code update, that's the likely cause — check the Claude
Code release notes and open an issue here.

**Settings change in one overlay didn't show up in the other.**
That's expected: the overlay symlinks `settings.json` to `~/.claude/`, so
edits there are shared. If your symlink points elsewhere, recreate the
overlay.

## Layout

```
claude-multi-account/
├── README.md
├── LICENSE
├── install.sh                   # adds claude-as function + PATH to your rc
├── uninstall.sh                 # removes the rc block (preserves overlays)
├── bin/
│   └── claude-account           # add | remove | list overlays
├── lib/
│   └── security-shim.sh         # the one-line shim copied into each overlay
└── examples/
    └── statusline-account-tag.sh
```

## License

MIT — see [LICENSE](LICENSE).
