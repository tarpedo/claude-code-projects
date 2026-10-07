#!/usr/bin/env bash
# install.sh — install or remove ccpr for the current user.
#
#   ./install.sh               install (safe to re-run)
#   ./install.sh --uninstall   remove everything install.sh added
#
# BIN_DIR (default ~/.local/bin) chooses where `ccpr` goes. Projects,
# the session manifest and Claude Code transcripts are never deleted.

set -euo pipefail

BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccpr"
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMUX_CONF=$HOME/.tmux.conf
BASHRC=$HOME/.bashrc
SETTINGS=$HOME/.claude/settings.json
SOURCE_LINE="source-file $CONFIG_DIR/ccpr.tmux.conf"

say() { printf '  %s\n' "$*"; }

render() {                       # render TEMPLATE → stdout with @BIN@ filled in
    sed "s|@BIN@|$BIN_DIR|g" "$SRC/share/$1"
}

# hooks merge|unmerge — edit Claude Code hooks, leave the rest of settings alone
hooks() {
    local ours
    ours=$(mktemp)
    render claude-hooks.json > "$ours"
    python3 - "$1" "$SETTINGS" "$ours" <<'PY'
import json, os, sys
mode, path, ours_path = sys.argv[1:4]
ours = json.load(open(ours_path))["hooks"]
cfg = json.load(open(path)) if os.path.exists(path) else {}
hooks = cfg.setdefault("hooks", {})
changed = 0
for event, groups in ours.items():
    have = hooks.setdefault(event, [])
    for group in groups:
        if mode == "merge" and group not in have:
            have.append(group); changed += 1
        elif mode == "unmerge" and group in have:
            have.remove(group); changed += 1
    if not have:
        del hooks[event]
if not hooks:
    cfg.pop("hooks")
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".ccpr-tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"  ✓ Claude Code hooks: {changed} {'added' if mode == 'merge' else 'removed'}")
PY
    rm -f "$ours"
}

do_install() {
    local dep
    for dep in tmux claude uuidgen flock awk python3; do
        command -v "$dep" >/dev/null || { say "✗ missing dependency: $dep"; exit 1; }
    done

    mkdir -p "$BIN_DIR" "$CONFIG_DIR"
    install -m 755 "$SRC/bin/ccpr" "$BIN_DIR/ccpr"
    render ccpr.tmux.conf > "$CONFIG_DIR/ccpr.tmux.conf"
    say "✓ $BIN_DIR/ccpr, $CONFIG_DIR/ccpr.tmux.conf"

    touch "$TMUX_CONF"
    grep -qxF "$SOURCE_LINE" "$TMUX_CONF" ||
        { printf '\n%s\n' "$SOURCE_LINE" >> "$TMUX_CONF"; say "✓ $TMUX_CONF"; }

    touch "$BASHRC"
    grep -q '^# >>> ccpr >>>' "$BASHRC" ||
        { printf '\n' >> "$BASHRC"; render bashrc.sh >> "$BASHRC"; say "✓ $BASHRC"; }

    [[ -f $SETTINGS ]] && cp "$SETTINGS" "$SETTINGS.bak-ccpr"
    hooks merge

    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "! add $BIN_DIR to PATH" ;; esac
    echo
    say "Next: tmux source-file ~/.tmux.conf; ccpr add NAME DIR; press F1."
}

do_uninstall() {
    rm -f "$BIN_DIR/ccpr" "$CONFIG_DIR/ccpr.tmux.conf"
    say "✓ removed $BIN_DIR/ccpr, ccpr.tmux.conf"
    if [[ -f $TMUX_CONF ]]; then
        grep -vxF "$SOURCE_LINE" "$TMUX_CONF" > "$TMUX_CONF.ccpr-tmp" || true
        mv "$TMUX_CONF.ccpr-tmp" "$TMUX_CONF"
    fi
    if [[ -f $BASHRC ]]; then
        sed -i '/^# >>> ccpr >>>$/,/^# <<< ccpr <<<$/d' "$BASHRC"
    fi
    [[ -f $SETTINGS ]] && hooks unmerge
    say "projects and saved sessions are kept in $CONFIG_DIR and ${XDG_STATE_HOME:-$HOME/.local/state}/ccpr"
}

case ${1:-} in
    "")           do_install ;;
    --uninstall)  do_uninstall ;;
    *)            echo "usage: $0 [--uninstall]" >&2; exit 2 ;;
esac
