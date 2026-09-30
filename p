#!/usr/bin/env bash
# p — crash-proof Claude Code sessions for tmux. One script for everything:
#   p            project menu (F1): pick a number, land in the project's tmux session
#   p restore    after tmux dies, recreate all windows from the manifest with claude
#   p forget     close a window and drop it from the manifest
# Projects are listed in PROJECTS below.
#
# Claude runs through `c`, which binds every window to a session id in
# ~/.config/p/sessions.tsv ("project window dir id"); restore reopens the
# windows and `c` resumes each session.

MANIFEST="${P_MANIFEST:-$HOME/.config/p/sessions.tsv}"
mkdir -p "${MANIFEST%/*}"; touch "$MANIFEST"

# name:directory — one tmux session per project
PROJECTS=(
    "example:$HOME/code/example"
)

TAB_CMD="$HOME/bin/c; exec bash"     # what a restored window runs

names=(); paths=()
for entry in "${PROJECTS[@]}"; do
    names+=("${entry%%:*}"); paths+=("${entry#*:}")
done

path_of() {            # project directory by name (empty if unknown)
    for i in "${!names[@]}"; do
        [ "${names[$i]}" = "$1" ] && { echo "${paths[$i]}"; return; }
    done
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

case "$1" in
    restore) restore; exit ;;
    forget)  forget;  exit ;;
esac

open=$(tmux ls -F '#S' 2>/dev/null)
echo
for i in "${!names[@]}"; do
    n=${names[$i]}
    if grep -qx "$n" <<< "$open"; then
        tabs=$(tmux list-windows -t "=$n" -F '#W' | paste -sd ' ')
        printf "  %2d) %-12s ● %s\n" $((i + 1)) "$n" "$tabs"
    else
        saved=$(awk -F'\t' -v p="$n" '$1==p {print $2}' "$MANIFEST" | paste -sd ' ')
        printf "  %2d) %-12s %s\n" $((i + 1)) "$n" "${saved:+○ $saved}"
    fi
done
echo
echo "  ● open (windows listed)   ○ saved in the manifest, not running"
echo "   r) restore all from manifest    f) forget a window"
echo
read -rp "  Project #: " num
case "$num" in
    r) restore; read -rp "  Enter → menu"; exec "$0" ;;
    f) forget;  exec "$0" ;;
esac

[[ $num =~ ^[0-9]+$ ]] || exit 0          # not a number (empty, letters) — quit
idx=$((num - 1))
[ "$idx" -ge 0 ] && [ -n "${names[$idx]}" ] || exit 0
n=${names[$idx]}

if ! tmux has-session -t "=$n" 2>/dev/null; then
    read -rp "  First window name [main]: " tab
    tmux new -d -s "$n" -n "${tab:-main}" -c "${paths[$idx]}"
fi

if [ -n "$TMUX" ]; then
    tmux switch-client -t "=$n"
else
    tmux attach -t "=$n"
fi
