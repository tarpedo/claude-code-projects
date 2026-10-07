# p

tmux project menu that keeps [Claude Code](https://docs.claude.com/en/docs/claude-code) sessions alive across tmux crashes.

- `p` (or `F1`) — project menu: running projects with their windows, and saved windows of stopped ones.
- `F2` — new window running claude, bound to a Claude Code session id in `~/.config/p/sessions.tsv`. `F2` with the same name later resumes the same conversation (`c` / `p claude` does the same in any window).
- `F5` renames a window together with its binding, `F8` opens a plain shell, `F7` shows a cheat sheet.
- `exit` in a window's shell forgets the window; a crash (SIGHUP) does not.
- Restore is automatic: the first tmux server start after a crash or reboot recreates every saved window and resumes its session (`p restore` / menu `r` by hand). Requires `flock`.
- `p forget` (menu `f`) — close a window and drop it from the manifest.
- Agent state next to every window name: `◐` working, `!` waiting for you, `✓` answered; the status line lists windows in all projects that wait for you.

## Setup

```bash
cp p agent-status ~/bin/ && ln -s p ~/bin/c && cp tmux.conf ~/.tmux.conf
cat bashrc.snippet >> ~/.bashrc
```

Merge `claude-hooks.json` into `~/.claude/settings.json`, then register projects:
`p add NAME DIR` (or menu `a`; `p remove` / menu `d` unregisters). They live in
`~/.config/p/projects.tsv`. Requires `uuidgen`.

## Agent state

Claude Code hooks call `agent-status work|ask|done|clear`, which sets the tmux
window option `@agent`; `window-status-format` and the menu display it.

| Hook | State |
|---|---|
| `UserPromptSubmit`, `PostToolUse` | `◐` |
| `Notification` (permission, elicitation), `PreToolUse` on `AskUserQuestion` | `!` |
| `Stop` | `✓` |
| `SessionEnd` | cleared |
| `SessionStart` | `p bind` — binds sessions started by hand, via `/resume` or `/clear` (not `claude -p`) |
