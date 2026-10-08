# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-10-08

First public release. `p` becomes `ccpr`.

### Added
- `install.sh` with `--uninstall`, templated paths (`BIN_DIR`).
- bats test suite running against an isolated tmux server and a Claude Code stub; shellcheck.
- `ccpr status` replaces the separate `agent-status` script.

### Changed
- State follows XDG: projects in `~/.config/ccpr`, the manifest in `~/.local/state/ccpr`.
- All manifest writes are atomic (temp file in the same directory + `mv`).
- `restore` reports windows tmux refused to create and exits non-zero.

### Removed
- The `c` shortcut: use `ccpr claude`, or simply F2.

### Fixed
- A tmux server started by `restore` no longer inherits the restore lock.

## [0.6.0] — 2026-10-08
### Added
- Auto-restore on the first tmux server start (`@p_restored`), serialized with `flock`.
- `p waiting`: status-line segment listing windows whose agent waits for you.

## [0.5.0] — 2026-10-08
### Added
- `SessionStart` hook → `p bind`: sessions started by hand, via `/resume` or `/clear` are bound too.

## [0.4.0] — 2026-10-08
### Added
- Projects live in `projects.tsv`; `p add` / `p remove`.

## [0.3.0] — 2026-10-07
### Changed
- `c` merged into `p` (`p claude`; `c` is a symlink).
### Added
- F2 opens a window with claude, F8 a plain shell, F5 renames a window with its binding.
- `exit` in a window forgets it (bash `EXIT` trap), SIGHUP does not.

## [0.2.0] — 2026-10-07
### Added
- Agent state glyphs ◐ ! ✓ via Claude Code hooks (`agent-status`).

## [0.1.0] — 2026-09-30
### Added
- Session manifest binding project/window to a Claude Code session id; `c` wrapper.
- `p restore` and `p forget`.

## [0.0.1] — 2026-09-30
### Added
- `p`: tmux project menu on F1 and function-key bindings.

[1.0.0]: https://github.com/tarpedo/claude-code-projects/releases/tag/v1.0.0
