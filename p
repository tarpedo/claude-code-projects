#!/usr/bin/env bash
# p — tmux project menu (F1): pick a number, land in the project's tmux session.
# Each project is a tmux session started in the project directory.

# name:directory — one tmux session per project
PROJECTS=(
    "example:$HOME/code/example"
)

names=(); paths=()
for entry in "${PROJECTS[@]}"; do
    names+=("${entry%%:*}"); paths+=("${entry#*:}")
done

open=$(tmux ls -F '#S' 2>/dev/null)
echo
for i in "${!names[@]}"; do
    n=${names[$i]}
    if grep -qx "$n" <<< "$open"; then
        tabs=$(tmux list-windows -t "=$n" -F '#W' | paste -sd ' ')
        printf "  %2d) %-12s ● %s\n" $((i + 1)) "$n" "$tabs"
    else
        printf "  %2d) %s\n" $((i + 1)) "$n"
    fi
done
echo
echo "  ● open (windows listed)"
echo
read -rp "  Project #: " num

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
