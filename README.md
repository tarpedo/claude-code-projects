# p

tmux project menu that keeps [Claude Code](https://docs.claude.com/en/docs/claude-code) sessions alive across tmux crashes.

- `p` (or `F1`) — project menu: running projects with their windows, and saved windows of stopped ones.
- `c` — run claude in a window. The window is bound to a Claude Code session id in `~/.config/p/sessions.tsv`; next time `c` in that window resumes the same conversation.
- `p restore` (menu `r`) — after tmux dies, recreate every saved window and resume its session.
- `p forget` (menu `f`) — close a window and drop it from the manifest.
- Agent state next to every window name: `◐` working, `!` waiting for you, `✓` answered.

## Setup

```bash
cp p c agent-status ~/bin/ && cp tmux.conf ~/.tmux.conf
```

Merge `claude-hooks.json` into `~/.claude/settings.json` and edit the `PROJECTS`
array at the top of `p`. Requires `uuidgen`.

## Agent state

Claude Code hooks call `agent-status work|ask|done|clear`, which sets the tmux
window option `@agent`; `window-status-format` and the menu display it.

| Hook | State |
|---|---|
| `UserPromptSubmit`, `PostToolUse` | `◐` |
| `Notification` (permission, elicitation), `PreToolUse` on `AskUserQuestion` | `!` |
| `Stop` | `✓` |
| `SessionEnd` | cleared |
