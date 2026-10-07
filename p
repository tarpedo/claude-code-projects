#!/usr/bin/env bash
# p — crash-proof Claude Code sessions for tmux. One script for everything:
#   p            project menu (F1): pick a number, land in the project's tmux session
#   p claude     claude bound to the current window (same as `c`, a symlink here)
#   p restore    after tmux dies, recreate all windows from the manifest with claude
#   p forget     close a window and drop it from the manifest
#   p rename     rename a window together with its manifest row (F5)
#   p help       cheat sheet (F7)
# Projects are listed in PROJECTS below.
#
# Every new window (F2), a project's first window and restore all run
# `p claude`: if ~/.config/p/sessions.tsv has a row "project window dir id"
# and the transcript still exists — claude --resume, otherwise a new id and row.
# Leaving claude drops you to bash; `exit` there removes the window from the
# manifest (EXIT trap in ~/.bashrc), so restore only brings back open work.

MANIFEST="${P_MANIFEST:-$HOME/.config/p/sessions.tsv}"
mkdir -p "${MANIFEST%/*}"; touch "$MANIFEST"

# name:directory — one tmux session per project
PROJECTS=(
    "example:$HOME/code/example"
)

ME="$HOME/bin/p"
TAB_CMD="$ME claude; exec bash"     # what a new window runs

[ "${0##*/}" = c ] && set -- claude "$@"     # old `c` → p claude

names=(); paths=()
for entry in "${PROJECTS[@]}"; do
    names+=("${entry%%:*}"); paths+=("${entry#*:}")
done

path_of() {            # project directory by name (empty if unknown)
    for i in "${!names[@]}"; do
        [ "${names[$i]}" = "$1" ] && { echo "${paths[$i]}"; return; }
    done
}

id_of() {              # session id of "project/window" from the manifest
    awk -F'\t' -v p="$1" -v t="$2" '$1==p && $2==t {print $4; exit}' "$MANIFEST"
}

without() {            # manifest without the "project/window" row → stdout
    awk -F'\t' -v p="$1" -v t="$2" '!($1==p && $2==t)' "$MANIFEST"
}

claude_tab() {         # formerly ~/bin/c
    [ -z "$TMUX" ] && exec claude "$@"

    local proj tab id tmp
    proj=$(tmux display-message -p -t "$TMUX_PANE" '#S')
    tab=$(tmux display-message -p -t "$TMUX_PANE" '#W')
    if [ -z "$tab" ]; then
        read -rp "  Window name: " tab
        [ -n "$tab" ] || { echo "  not starting claude in an unnamed window" >&2; return 1; }
        tmux rename-window -t "$TMUX_PANE" "$tab"
    fi

    id=$(id_of "$proj" "$tab")
    if [ -n "$id" ] && ls "$HOME"/.claude/projects/*/"$id".jsonl >/dev/null 2>&1; then
        exec claude --resume "$id" "$@"
    fi

    # no row, or the transcript is gone — start a new session
    id=$(uuidgen)
    tmp=$(mktemp)
    without "$proj" "$tab" > "$tmp"
    printf '%s\t%s\t%s\t%s\n' "$proj" "$tab" "$PWD" "$id" >> "$tmp"
    mv "$tmp" "$MANIFEST"
    exec claude --session-id "$id" "$@"
}

rename() {             # F5: rename-window + the same key in the manifest
    local wid=$1 new=$2 proj old tmp
    [ -n "$wid" ] && [ -n "$new" ] || return
    proj=$(tmux display-message -p -t "$wid" '#S')
    old=$(tmux display-message -p -t "$wid" '#W')
    [ "$old" = "$new" ] && return
    if [ -n "$(id_of "$proj" "$new")" ]; then
        tmux display-message "$proj already has a window named '$new'"
        return
    fi
    tmux rename-window -t "$wid" "$new"
    tmp=$(mktemp)
    awk -F'\t' -v OFS='\t' -v p="$proj" -v o="$old" -v n="$new" \
        '$1==p && $2==o {$2=n} 1' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
}

restore() {
    local proj tab cwd id made=0 skipped=0
    [ -s "$MANIFEST" ] || { echo "  manifest is empty: $MANIFEST"; return; }

    while IFS=$'\t' read -r proj tab cwd id; do
        [ -z "$proj" ] && continue
        [ -z "$tab" ] && { echo "  ✗ $proj — row without a window name (remove it with f)"; continue; }
        [ -d "$cwd" ] || cwd=$(path_of "$proj")
        [ -d "$cwd" ] || { echo "  ✗ $proj/$tab — directory is gone"; continue; }

        if ! tmux has-session -t "=$proj" 2>/dev/null; then
            tmux new -d -s "$proj" -n "$tab" -c "$cwd" "$TAB_CMD"
        elif tmux list-windows -t "=$proj" -F '#W' | grep -qxF "$tab"; then
            skipped=$((skipped + 1)); continue     # window is alive — leave it
        else
            tmux new-window -d -t "=$proj" -n "$tab" -c "$cwd" "$TAB_CMD"
        fi
        made=$((made + 1))
        echo "  ● $proj/$tab  ${id:0:8}"
    done < "$MANIFEST"

    echo
    echo "  restored windows: $made, already open: $skipped"
}

forget() {
    local -a rows; local n i
    mapfile -t rows < "$MANIFEST"
    [ ${#rows[@]} -gt 0 ] || { echo "  manifest is empty"; return; }
    echo
    for i in "${!rows[@]}"; do
        IFS=$'\t' read -r proj tab cwd id <<< "${rows[$i]}"
        printf "  %2d) %-12s %-16s %s\n" $((i + 1)) "$proj" "${tab:-(unnamed)}" "${id:0:8}"
    done
    echo
    read -rp "  Forget # — close the window and drop it (empty: cancel): " n
    [ -z "$n" ] && return
    [[ $n =~ ^[0-9]+$ ]] || return
    i=$((n - 1))
    [ "$i" -ge 0 ] && [ -n "${rows[$i]}" ] || return
    IFS=$'\t' read -r proj tab cwd id <<< "${rows[$i]}"
    unset 'rows[i]'
    printf '%s\n' "${rows[@]}" > "$MANIFEST"
    echo "  dropped from the manifest"
    if [ -n "$tab" ] && tmux has-session -t "=$proj" 2>/dev/null \
       && tmux list-windows -t "=$proj" -F '#W' | grep -qxF "$tab"; then
        tmux kill-window -t "=$proj:=$tab" && echo "  closed $proj/$tab"
    fi
}

help() {
    cat <<'TXT'
  HOW TO USE IT

  Open a project        p or F1 → number (a new session starts with claude)
  New task              F2 → task name — claude starts and the window remembers it
  Plain shell window    F8 → name
  Back to a task        F2 → the same name (resumes), or type  c  in its shell
  Switch windows        F3 / F4       Detach        F6
  Rename                F5 — the session stays bound to the window

  tmux crashed          p → r — every saved window comes back with its session
  Done with a task      leave claude (/exit), then type  exit  in the shell —
                        the window closes and leaves the manifest.
                        Without exit the window stays restorable.
  Forget from outside   p → f

  Agent state           next to the window name and in the menu:
                        ◐ working   ! waiting for you   ✓ answered

  Manifest: ~/.config/p/sessions.tsv   Script: ~/bin/p  (c → p claude)
TXT
}

drop() {               # quietly drop a window from the manifest (EXIT trap in ~/.bashrc)
    local proj=$1 tab=$2 tmp
    if [ $# -eq 1 ]; then              # given a pane id (%N)
        proj=$(tmux display-message -p -t "$1" '#S' 2>/dev/null)
        tab=$(tmux display-message -p -t "$1" '#W' 2>/dev/null)
    fi
    [ -n "$proj" ] && [ -n "$tab" ] || return 0
    tmp=$(mktemp)
    without "$proj" "$tab" > "$tmp" && mv "$tmp" "$MANIFEST"
}

case "$1" in
    claude)  shift; claude_tab "$@"; exit ;;
    drop)    shift; drop "$@"; exit ;;
    rename)  rename "$2" "$3"; exit ;;
    restore) restore; exit ;;
    forget)  forget;  exit ;;
    help)    help; read -rp "  Enter → close"; exit ;;
esac

open=$(tmux ls -F '#S' 2>/dev/null)
echo
for i in "${!names[@]}"; do
    n=${names[$i]}
    if grep -qx "$n" <<< "$open"; then
        tabs=$(tmux list-windows -t "=$n" -F '#W#{?@agent,#{@agent},}' | paste -sd ' ')
        printf "  %2d) %-12s ● %s\n" $((i + 1)) "$n" "$tabs"
    else
        saved=$(awk -F'\t' -v p="$n" '$1==p {print $2}' "$MANIFEST" | paste -sd ' ')
        printf "  %2d) %-12s %s\n" $((i + 1)) "$n" "${saved:+○ $saved}"
    fi
done
echo
echo "  ● open (windows listed)   ○ saved in the manifest, not running"
echo "  claude in a window:  ◐ working   ! waiting for you   ✓ answered"
echo "   r) restore all from manifest    f) forget a window    h) help"
echo
read -rp "  Project #: " num
case "$num" in
    r) restore; read -rp "  Enter → menu"; exec "$0" ;;
    f) forget;  exec "$0" ;;
    h) help; read -rp "  Enter → menu"; exec "$0" ;;
esac

[[ $num =~ ^[0-9]+$ ]] || exit 0          # not a number (empty, letters) — quit
idx=$((num - 1))
[ "$idx" -ge 0 ] && [ -n "${names[$idx]}" ] || exit 0
n=${names[$idx]}

if ! tmux has-session -t "=$n" 2>/dev/null; then
    read -rp "  First window name [main]: " tab
    tmux new -d -s "$n" -n "${tab:-main}" -c "${paths[$idx]}" "$TAB_CMD"
fi

if [ -n "$TMUX" ]; then
    tmux switch-client -t "=$n"
else
    tmux attach -t "=$n"
fi
