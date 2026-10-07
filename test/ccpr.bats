#!/usr/bin/env bats

load helpers

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
    [[ $output == *"already exists"* ]]
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
    [[ $output == *"restored: 2, already running: 0"* ]]
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

@test "restore is idempotent" {
    manifest_row demo main "$HOME/work" 11111111-1111-1111-1111-111111111111
    ccpr restore
    run ccpr restore
    [[ $output == *"restored: 0, already running: 1"* ]]
    [ "$(windows demo)" = "main" ]
}

@test "restore falls back to the project directory" {
    ccpr add demo "$HOME/work"
    manifest_row demo main "$HOME/gone" 11111111-1111-1111-1111-111111111111
    run ccpr restore
    [ "$status" -eq 0 ]
    [ "$(tmux display-message -p -t '=demo:' '#{pane_current_path}')" = "$HOME/work" ]
}

@test "rename moves the binding and refuses duplicates" {
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    ccpr restore
    wid=$(tmux list-windows -t =demo -F '#{window_id} #W' | awk '$2=="one" {print $1}')
    ccpr rename "$wid" uno
    [ "$(cut -f2 "$MANIFEST" | paste -sd'|')" = "uno|two" ]
    run ccpr rename "$wid" two
    [ "$status" -eq 1 ]
    [ "$(windows demo)" = "uno|two" ]
}

@test "drop forgets the window of a pane" {
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    ccpr restore
    pane=$(tmux list-panes -a -F '#{pane_id} #W' | awk '$2=="one" {print $1}')
    ccpr drop "$pane"
    [ "$(cut -f2 "$MANIFEST")" = "two" ]
}

@test "forget drops the row and closes the window" {
    fake_transcript 11111111-1111-1111-1111-111111111111
    fake_transcript 22222222-2222-2222-2222-222222222222
    manifest_row demo one "$HOME/work" 11111111-1111-1111-1111-111111111111
    manifest_row demo two "$HOME/work" 22222222-2222-2222-2222-222222222222
    ccpr restore
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
    [[ $(ccpr waiting) == *"waiting: demo/two"* ]]
    TMUX_PANE=$pane ccpr status clear
    [ -z "$(ccpr waiting)" ]
}

@test "unknown commands fail loudly" {
    run ccpr frobnicate
    [ "$status" -eq 1 ]
    [[ $output == *"unknown command"* ]]
}
