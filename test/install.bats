#!/usr/bin/env bats

load helpers

INSTALL="$BATS_TEST_DIRNAME/../install.sh"

setup_file() {
    # install.sh checks dependencies; uuidgen may be absent in containers
    local tool
    for tool in uuidgen python3; do
        command -v "$tool" >/dev/null || skip "missing $tool"
    done
}

@test "install wires tmux, bash and Claude Code hooks once" {
    mkdir -p "$HOME/.claude"
    echo '{"model": "opus", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "mine"}]}]}}' \
        > "$HOME/.claude/settings.json"
    "$INSTALL" && "$INSTALL"

    [ -x "$HOME/.local/bin/ccpr" ]
    [ "$(grep -c ccpr.tmux.conf "$HOME/.tmux.conf")" -eq 1 ]
    [ "$(grep -c '>>> ccpr >>>' "$HOME/.bashrc")" -eq 1 ]
    grep -q "$HOME/.local/bin/ccpr open" "$HOME/.config/ccpr/ccpr.tmux.conf"
    run python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); print(c["model"], len(c["hooks"]), len(c["hooks"]["Stop"]))' \
        "$HOME/.claude/settings.json"
    [ "$output" = "opus 7 2" ]
}

@test "uninstall leaves only what was there before" {
    mkdir -p "$HOME/.claude"
    echo 'set -g mouse on' > "$HOME/.tmux.conf"
    echo 'alias ll="ls -l"' > "$HOME/.bashrc"
    echo '{"model": "opus"}' > "$HOME/.claude/settings.json"
    "$INSTALL"
    "$INSTALL" --uninstall

    [ ! -e "$HOME/.local/bin/ccpr" ]
    [ "$(grep -v '^$' "$HOME/.tmux.conf")" = 'set -g mouse on' ]
    [ "$(grep -v '^$' "$HOME/.bashrc")" = 'alias ll="ls -l"' ]
    [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])))' "$HOME/.claude/settings.json")" = "{'model': 'opus'}" ]
}

@test "zsh gets the same exit trap, and loses it on uninstall" {
    echo 'setopt autocd' > "$HOME/.zshrc"
    "$INSTALL" && "$INSTALL"
    [ "$(grep -c '>>> ccpr >>>' "$HOME/.zshrc")" -eq 1 ]
    "$INSTALL" --uninstall
    [ "$(grep -v '^$' "$HOME/.zshrc")" = 'setopt autocd' ]
}

@test "reinstall replaces an older block in place" {
    printf '%s\n' 'alias a=1' '# >>> ccpr >>>' 'old trap' '# <<< ccpr <<<' 'alias b=2' > "$HOME/.bashrc"
    "$INSTALL"
    [ -z "$(grep 'old trap' "$HOME/.bashrc")" ]   # a bare `! grep` never fails a bats test
    grep -q 'pane_pid' "$HOME/.bashrc"
    [ "$(grep -c '>>> ccpr >>>' "$HOME/.bashrc")" -eq 1 ]
    [ "$(head -1 "$HOME/.bashrc")" = 'alias a=1' ]
    [ "$(tail -1 "$HOME/.bashrc")" = 'alias b=2' ]
}
