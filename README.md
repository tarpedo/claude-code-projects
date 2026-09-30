# p

A tiny tmux project menu.

`p` (or `F1` inside tmux) lists your projects, shows which ones are running and
with which windows, and drops you into the project's tmux session — creating it
in the project directory if needed.

## Setup

```bash
cp p ~/bin/ && cp tmux.conf ~/.tmux.conf
```

Edit the `PROJECTS` array at the top of `p`.

| Key | Action |
|---|---|
| `F1` | project menu |
| `F2` | new window |
| `F3` / `F4` | previous / next window |
| `F5` | rename window |
| `F6` | detach |
