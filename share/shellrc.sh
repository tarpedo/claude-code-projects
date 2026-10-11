# >>> ccpr >>>
# `exit` in a tmux window forgets that window, so restore skips closed work.
# Plain POSIX sh: the same block serves bash and zsh.
# SIGHUP (tmux died, window killed) must not: that is what the manifest is for.
# Only the window's own shell (the pane process) gets the trap: leaving a
# nested shell started inside it must not forget the window.
if [ -n "$TMUX" ] &&
    [ "$$" = "$(tmux display-message -p -t "$TMUX_PANE" '#{pane_pid}' 2>/dev/null)" ]; then
    trap 'CCPR_HUP=1; exit' HUP
    trap '[ -z "$CCPR_HUP" ] && "@BIN@/ccpr" drop "$TMUX_PANE"' EXIT
fi
# <<< ccpr <<<
