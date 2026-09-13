# p

tmux project menu that keeps [Claude Code](https://docs.claude.com/en/docs/claude-code) sessions alive across tmux crashes.

- `p` (or `F1`) — project menu: running projects with their windows, and saved windows of stopped ones.
- `c` — run claude in a window. The window is bound to a Claude Code session id in `~/.config/p/sessions.tsv`; next time `c` in that window resumes the same conversation.
- `p restore` (menu `r`) — after tmux dies, recreate every saved window and resume its session.
- `p forget` (menu `f`) — close a window and drop it from the manifest.

## Setup

```bash
cp p c ~/bin/ && cp tmux.conf ~/.tmux.conf
```

Edit the `PROJECTS` array at the top of `p`. Requires `uuidgen`.

## Manifest

```
project ⇥ window ⇥ directory ⇥ session id
```

`c` passes a pre-generated id with `claude --session-id`, so the binding is known before the session even starts.
