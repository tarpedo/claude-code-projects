# Claude Code Projects

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Crash-proof [Claude Code](https://docs.claude.com/en/docs/claude-code) sessions in tmux.**
One bash script, `ccpr`, that turns tmux into a project manager for parallel AI agents:

- **Projects are tmux sessions, tasks are windows.** `F1` opens the project menu; `F2` opens a window with Claude for a new task.
- **Every window remembers its conversation.** A project/window pair is bound to a Claude Code session id. `F2` with an existing task name brings you back to the same conversation.
- **tmux crashes are a non-event.** When the tmux server starts again, every window you did not close comes back, each resuming its own session.
- **See who is waiting for you.** Each window shows its agent state: `◐` working, `!` waiting for a permission or an answer, `✓` answered. The status line lists every window, in every project, where an agent is blocked on you.

```
   1) shop         ● main✓ invoice! import◐
   2) blog         ○ drafts
   3) docs

  ● running (windows)   ○ saved, not running   ◐ working  ! waiting  ✓ answered
   r) restore all    f) forget a window    a) add project    d) remove project    h) help

  Project #:
```

## Why

tmux-resurrect can restore windows and even relaunch `claude`, but it cannot know *which* conversation lived in which window. GUI agent managers exist, but they are mostly macOS apps. This project needs nothing beyond tmux, bash and an SSH session.

## Install

Requirements: Linux, bash ≥ 4, tmux ≥ 3.2, Claude Code, `uuidgen`, `flock`, `python3` (installer only).

```bash
git clone https://github.com/tarpedo/claude-code-projects.git
cd claude-code-projects
./install.sh                     # BIN_DIR=~/bin ./install.sh to choose the location
tmux source-file ~/.tmux.conf
ccpr add myproject ~/code/myproject
```

The installer is idempotent and reversible (`./install.sh --uninstall`). It changes:

| What | Where |
|---|---|
| `ccpr` | `$BIN_DIR` (default `~/.local/bin`) |
| key bindings, status line, auto-restore | `~/.config/ccpr/ccpr.tmux.conf`, sourced from `~/.tmux.conf` |
| `exit` trap that forgets closed windows | `~/.bashrc`, between `# >>> ccpr >>>` markers |
| Claude Code hooks | merged into `~/.claude/settings.json` (backup: `settings.json.bak-ccpr`) |

## Keys

| Key | Action |
|---|---|
| `F1` | project menu |
| `F2` | new window running Claude (or back to the task with that name) |
| `F3` / `F4` | previous / next window |
| `F5` | rename a window and keep its session bound |
| `F6` | detach |
| `F7` | cheat sheet |

## How it works

```
~/.local/state/ccpr/sessions.tsv
project ⇥ window ⇥ directory ⇥ session id
shop      invoice  /srv/shop    0f8e2c4a-7b1d-4e53-9a26-c3d5b8e1f047
```

**Binding.** `ccpr claude` looks up the current window in the manifest. If a row exists and Claude Code still has the transcript, it runs `claude --resume <id>`. Otherwise it generates an id, writes the row first, and runs `claude --session-id <id>`. Because ccpr chooses the id, it never has to guess which conversation belongs to a window.

**Restore.** `ccpr restore` walks the manifest and creates missing sessions and windows, each running `ccpr claude`, so binding logic lives in one place. It is idempotent and runs under `flock`. `ccpr.tmux.conf` triggers it once per server lifetime, guarded by a server option, so reloading the config does not repeat it. The menu also triggers it when tmux is not running at all.

**Closing.** When you leave Claude, the window drops to a shell. Typing `exit` there forgets the window. The trap deliberately ignores `SIGHUP`, so a dying tmux server never wipes the manifest. Anything you did not close explicitly survives a crash.

**Hooks.** Claude Code hooks keep the binding and the state glyphs current:

| Claude Code event | ccpr |
|---|---|
| `SessionStart` | `ccpr bind`: binds sessions started by hand, via `/resume` or `/clear`, but not `claude -p` subprocesses |
| `UserPromptSubmit`, `PostToolUse` | `◐` |
| `Notification` (permission, elicitation), `PreToolUse` on `AskUserQuestion` | `!` |
| `Stop` | `✓` |
| `SessionEnd` | clear |

State lives in the tmux window option `@agent`. It disappears with the window, and any format string can read it without spawning a process.

## Commands

```
ccpr                     project menu
ccpr claude [ARGS…]      claude bound to the current window
ccpr restore             recreate all windows from the manifest
ccpr forget              close a window and drop it from the manifest
ccpr rename WID NAME     rename a window with its binding
ccpr add [NAME] [DIR]    register a project
ccpr remove [NAME]       unregister a project (the directory is untouched)
ccpr help | version
```

`CCPR_PROJECTS` and `CCPR_MANIFEST` override file locations. `XDG_CONFIG_HOME` and `XDG_STATE_HOME` are respected.

## Development

```bash
make check      # shellcheck + bats
```

Tests run against a throwaway tmux server, a temporary `HOME` and a stub `claude` (`test/stub/claude`), so they never touch your real sessions.

## Limitations

- The window name is the key, so window names must be unique within a project.
- Project names become tmux session names: `[A-Za-z0-9_-]+`.
- ccpr restores windows and conversations, not pane layouts. Combine it with tmux-resurrect if you need layouts.
- Linux only (`/proc`, `flock`).

## License

[MIT](LICENSE)
