#!/usr/bin/env bash
# c — claude bound to the current tmux window.
# The manifest ~/.config/p/sessions.tsv maps "project window dir id": if the
# window already has a session and its transcript exists — claude --resume,
# otherwise a new id is generated, recorded, and passed via --session-id.
# Outside tmux it is just claude.

MANIFEST="${P_MANIFEST:-$HOME/.config/p/sessions.tsv}"
mkdir -p "${MANIFEST%/*}"; touch "$MANIFEST"

[ -z "$TMUX" ] && exec claude "$@"

proj=$(tmux display-message -p -t "$TMUX_PANE" '#S')
tab=$(tmux display-message -p -t "$TMUX_PANE" '#W')
if [ -z "$tab" ]; then
    read -rp "  Window name: " tab
    [ -n "$tab" ] || { echo "  not starting claude in an unnamed window" >&2; exit 1; }
    tmux rename-window -t "$TMUX_PANE" "$tab"
fi

id=$(awk -F'\t' -v p="$proj" -v t="$tab" '$1==p && $2==t {print $4; exit}' "$MANIFEST")
if [ -n "$id" ] && ls "$HOME"/.claude/projects/*/"$id".jsonl >/dev/null 2>&1; then
    exec claude --resume "$id" "$@"
fi

# no row, or the transcript is gone — start a new session
id=$(uuidgen)
tmp=$(mktemp)
awk -F'\t' -v p="$proj" -v t="$tab" '!($1==p && $2==t)' "$MANIFEST" > "$tmp"
printf '%s\t%s\t%s\t%s\n' "$proj" "$tab" "$PWD" "$id" >> "$tmp"
mv "$tmp" "$MANIFEST"
exec claude --session-id "$id" "$@"
