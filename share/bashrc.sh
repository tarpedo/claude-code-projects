# >>> ccpr >>>
# `exit` in a tmux window forgets that window, so restore skips closed work.
# SIGHUP (tmux died, window killed) must not: that is what the manifest is for.
if [ -n "$TMUX" ]; then
    trap 'CCPR_HUP=1; exit' HUP
    trap '[ -z "$CCPR_HUP" ] && "@BIN@/ccpr" drop "$TMUX_PANE"' EXIT
fi
# <<< ccpr <<<
