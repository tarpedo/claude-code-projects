#!/usr/bin/env bats

load helpers

# `[[ … ]] || false`: bash 3.2 does not fail a test on a false `[[ ]]` alone

@test "add registers a project with an absolute directory" {
    cd "$HOME"
    run ccpr add demo work
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/ccpr/projects.tsv")" = "demo	$HOME/work" ]
}

@test "add rejects names tmux cannot use and duplicates" {
    run ccpr add "my project" "$HOME/work"
    [ "$status" -eq 1 ]
    ccpr add demo "$HOME/work"
    run ccpr add demo "$HOME/work"
    [ "$status" -eq 1 ]
    [[ $output == *"already exists"* ]] || false
}

@test "claude outside tmux is plain claude" {
    run ccpr claude --version
    [ "$(cat "$CLAUDE_LOG")" = "--version" ]
    [ ! -s "$MANIFEST" ]
}

@test "restore recreates windows, names with spaces included" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo "two words" "$HOME/work" 22222222-2222-2222-2222-222222222222
    run ccpr restore
    [ "$status" -eq 0 ]
    [[ $output == *"restored: 2, already running: 0"* ]] || false
    [ "$(windows demo)" = "main|two words" ]
}

@test "a window resumes its session while the transcript exists" {
    id=11111111-1111-1111-1111-111111111111
    fake_transcript "$id"
    manifest_row demo main "$HOME/work" "$id"
    ccpr restore
    wait_for_claude 1
    [ "$(cat "$CLAUDE_LOG")" = "--resume $id" ]
}

@test "a window without a live transcript gets a new bound session" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    ccpr restore
    wait_for_claude 1
    new=$(cut -f4 "$MANIFEST")
    [ "$new" != 11111111-1111-1111-1111-111111111111 ]
    [ "$(cat "$CLAUDE_LOG")" = "--session-id $new" ]
}

@test "new session ids are lower case, as macOS uuidgen is not" {
    mkdir -p "$BATS_TEST_TMPDIR/mac"
    printf '#!/bin/sh\necho 0F8E2C4A-7B1D-4E53-9A26-C3D5B8E1F047\n' > "$BATS_TEST_TMPDIR/mac/uuidgen"
    chmod +x "$BATS_TEST_TMPDIR/mac/uuidgen"
    PATH="$BATS_TEST_TMPDIR/mac:$PATH"
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    ccpr restore
    wait_for_claude 1
    [ "$(cut -f4 "$MANIFEST")" = 0f8e2c4a-7b1d-4e53-9a26-c3d5b8e1f047 ]
}

@test "restore is idempotent" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    ccpr restore
    run ccpr restore
    [[ $output == *"restored: 0, already running: 1"* ]] || false
    [ "$(windows demo)" = "main" ]
}

@test "restore takes over a lock left by a dead process" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    sh -c 'exit 0' & dead=$!
    wait "$dead"
    mkdir "$MANIFEST.restore-lock"
    echo "$dead" > "$MANIFEST.restore-lock/pid"
    run ccpr restore
    [ "$status" -eq 0 ]
    [[ $output == *"restored: 1"* ]] || false
    [ ! -e "$MANIFEST.restore-lock" ]
}

@test "restore falls back to the project directory" {
    ccpr add demo "$HOME/work"
    manifest_row demo main "$HOME/gone" 11111111-1111-1111-1111-111111111111
    run ccpr restore
    [ "$status" -eq 0 ]
    [ "$(cd -P "$(tmux display-message -p -t '=demo:' '#{pane_current_path}')" && pwd)" = "$(cd -P "$HOME/work" && pwd)" ]
}

@test "rename moves the binding and refuses duplicates" {
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    fake_transcript 11111111-1111-1111-1111-111111111111
    fake_transcript 22222222-2222-2222-2222-222222222222
    ccpr restore
    wait_for_claude 2            # windows resume: no late manifest writes
    wid=$(tmux list-windows -t =demo -F '#{window_id} #W' | awk '$2=="one" {print $1}')
    ccpr rename "$wid" uno
    [ "$(cut -f2 "$MANIFEST" | paste -sd'|' -)" = "uno|two" ]
    run ccpr rename "$wid" two
    [ "$status" -eq 1 ]
    tmux new-window -d -t =demo: -n plain    # open, but never bound
    run ccpr rename "$wid" plain
    [ "$status" -eq 1 ]
    [ "$(windows demo)" = "uno|two|plain" ]
}

@test "drop forgets the window of a pane" {
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    fake_transcript 11111111-1111-1111-1111-111111111111
    fake_transcript 22222222-2222-2222-2222-222222222222
    ccpr restore
    wait_for_claude 2
    pane=$(tmux list-panes -a -F '#{pane_id} #W' | awk '$2=="one" {print $1}')
    ccpr drop "$pane"
    [ "$(cut -f2 "$MANIFEST")" = "two" ]
}

@test "closing a duplicate window keeps the original binding" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    ccpr restore
    wait_for_claude 1
    tmux new-window -d -t =demo: -n main
    pane=$(tmux list-panes -s -t =demo -F '#{pane_id}' | tail -1)
    ccpr drop "$pane"
    [ "$(cut -f2 "$MANIFEST")" = "main" ]
}

@test "exit forgets the window only from the window's own shell" {
    rc="$BATS_TEST_TMPDIR/rc"
    sed "s|@BIN@|${CCPR%/*}|g" "$BATS_TEST_DIRNAME/../share/shellrc.sh" > "$rc"
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    tmux new-session -d -s demo -n main "exec bash --rcfile '$rc' -i"
    pane=$(tmux list-panes -t =demo -F '#{pane_id}')
    # a nested shell: leaving it must keep the window
    tmux send-keys -t "$pane" "bash --rcfile '$rc' -i" Enter "touch '$BATS_TEST_TMPDIR/left'; exit" Enter
    eventually test -e "$BATS_TEST_TMPDIR/left"
    sleep 0.3
    [ -s "$MANIFEST" ]
    # the window's own shell: leaving it forgets the window
    tmux send-keys -t "$pane" exit Enter
    eventually test ! -s "$MANIFEST"
}

@test "F2 switches to an open window instead of starting a second claude" {
    id=11111111-1111-1111-1111-111111111111
    fake_transcript "$id"
    manifest_row demo main "$HOME/work" "$id"
    ccpr restore
    wait_for_claude 1
    sid=$(tmux display-message -p -t =demo: '#{session_id}')
    ccpr open "$sid" "$HOME/work" fresh
    [ "$(windows demo)" = "main|fresh" ]
    [ "$(tmux display-message -p -t =demo: '#W')" = "fresh" ]
    wait_for_claude 2
    ccpr open "$sid" "$HOME/work" main
    [ "$(windows demo)" = "main|fresh" ]
    [ "$(tmux display-message -p -t =demo: '#W')" = "main" ]
    sleep 0.3
    [ "$(grep -c -- "--resume $id" "$CLAUDE_LOG")" -eq 1 ]
}

@test "claude refuses to run in a second window with the same name" {
    id=11111111-1111-1111-1111-111111111111
    fake_transcript "$id"
    manifest_row demo main "$HOME/work" "$id"
    ccpr restore
    wait_for_claude 1
    err="$BATS_TEST_TMPDIR/err"
    tmux new-window -d -t =demo: -n main "'$CCPR' claude 2>'$err'; sleep 60"
    eventually grep -q "already has a window named 'main'" "$err"
    [ "$(wc -l < "$CLAUDE_LOG")" -eq 1 ]
}

@test "parallel first starts keep every binding" {
    tmux new-session -d -s demo -n w0 -c "$HOME/work"
    for i in $(seq 1 20); do
        tmux new-window -d -t =demo: -n "w$i" -c "$HOME/work" "sleep 0.5; '$CCPR' claude"
    done
    wait_for_claude 20
    [ "$(wc -l < "$MANIFEST")" -eq 20 ]
    [ "$(cut -f4 "$MANIFEST" | sort -u | wc -l)" -eq 20 ]
}

@test "forget drops the row and closes the window" {
    fake_transcript 11111111-1111-1111-1111-111111111111
    fake_transcript 22222222-2222-2222-2222-222222222222
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    ccpr restore
    wait_for_claude 2
    run ccpr forget <<< 1
    [ "$(cut -f2 "$MANIFEST")" = "two" ]
    [ "$(windows demo)" = "two" ]
}

@test "remove keeps saved sessions unless asked" {
    ccpr add demo "$HOME/work"
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    run ccpr remove demo <<< n
    [ ! -s "$HOME/.config/ccpr/projects.tsv" ]
    [ -s "$MANIFEST" ]
    ccpr add demo "$HOME/work"
    run ccpr remove demo <<< y
    [ ! -s "$MANIFEST" ]
}

@test "status glyphs show up in the waiting segment" {
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    ccpr restore
    pane=$(tmux list-panes -a -F '#{pane_id} #W' | awk '$2=="two" {print $1}')
    TMUX_PANE=$pane ccpr status ask
    [ "$(tmux display-message -p -t "$pane" '#{@agent}')" = "!" ]
    [[ $(ccpr waiting) == *"waiting: demo/two"* ]] || false
    TMUX_PANE=$pane ccpr status clear
    [ -z "$(ccpr waiting)" ]
}

@test "unknown commands fail loudly" {
    run ccpr frobnicate
    [ "$status" -eq 1 ]
    [[ $output == *"unknown command"* ]] || false
}
