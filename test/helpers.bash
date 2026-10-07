# Every test gets its own HOME, tmux server and Claude Code stub, so nothing
# touches the real tmux server, ~/.tmux.conf or ~/.claude.

CCPR="$BATS_TEST_DIRNAME/../bin/ccpr"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    # unix socket paths are limited to ~108 bytes: keep the tmux dir short
    TMUX_TMPDIR=$(mktemp -d /tmp/ccpr.XXXXXX)
    export TMUX_TMPDIR
    export CLAUDE_LOG="$BATS_TEST_TMPDIR/claude.log"
    export PATH="$BATS_TEST_DIRNAME/stub:$PATH"
    export SHELL=/bin/sh
    unset TMUX TMUX_PANE XDG_CONFIG_HOME XDG_STATE_HOME CCPR_PROJECTS CCPR_MANIFEST
    mkdir -p "$HOME/work"
    touch "$CLAUDE_LOG"
    MANIFEST="$HOME/.local/state/ccpr/sessions.tsv"
}

teardown() {
    tmux kill-server 2>/dev/null || true
    rm -rf "$TMUX_TMPDIR"
}

ccpr() { "$CCPR" "$@"; }

manifest_row() {                 # manifest_row PROJECT WINDOW DIR ID
    mkdir -p "${MANIFEST%/*}"
    printf '%s\t%s\t%s\t%s\n' "$@" >> "$MANIFEST"
}

fake_transcript() {              # make Claude Code "know" session ID
    mkdir -p "$HOME/.claude/projects/-work"
    touch "$HOME/.claude/projects/-work/$1.jsonl"
}

wait_for_claude() {              # wait_for_claude N — until N claude starts
    local _
    for _ in $(seq 50); do
        (( $(wc -l < "$CLAUDE_LOG") >= $1 )) && return 0
        sleep 0.1
    done
    echo "claude started $(wc -l < "$CLAUDE_LOG") times, expected $1" >&2
    return 1
}

windows() { tmux list-windows -t "=$1" -F '#W' | paste -sd'|'; }
