# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [1.1.1] — 2026-10-11

### Added
- README: a demo (`docs/demo.gif`, `docs/demo.cast`) and a comparison with agterm, the tmux-resurrect add-ons and Claude Code's agent view.

### Fixed
- F2 with the name of an open window opened a second window, and a second `claude --resume` on the same conversation. It now switches to that window; `ccpr claude` refuses to run in a duplicate, F5 refuses a name an unbound window already has.
- Hooks of many windows writing the manifest at once lost rows: rewrites now take a lock. `forget` drops its row by key, not by line number.
- `exit` from a shell nested inside a window forgot the window. Only the window's own shell carries the trap now; re-run `./install.sh` to update the block in `~/.bashrc` / `~/.zshrc` (the installer now replaces an older block in place).
- tmux 3.5 prints a tab in `-F` output as `_`, which broke the "! waiting" status-line segment (and F2's lookup); no tabs are used there any more.
- Tests: `[[ ]]` assertions did not fail under bash 3.2; tests that changed the manifest before the restored windows had started were flaky on a loaded machine.

## [1.1.0] — 2026-10-10

Runs on macOS.

### Added
- macOS support: bash 3.2, BSD userland, no `/proc` and no `flock` needed.
- zsh: the installer adds the exit trap to `~/.zshrc` too when zsh is the login shell or `~/.zshrc` exists.
- `make test-bash32` runs the suite under bash 3.2 in Docker.
- A logo.

### Changed
- `restore` serializes on a `mkdir` lock instead of `flock`; a lock left by a dead process is taken over.
- New session ids are lower-cased (macOS `uuidgen` prints upper case).
- The status bar hints list F1 to F7 in order, F2 reads "new".

### Fixed
- F3/F4 and F6 were missing from the status bar.
- Entering `0` in "remove project" removed the last project.

### Removed
- F8 (plain shell window): tmux's own `prefix c` does the same.
- `flock` from the dependencies.

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

## [0.6.0] — 2026-10-04
### Added
- Auto-restore on the first tmux server start (`@p_restored`), serialized with `flock`.
- `p waiting`: status-line segment listing windows whose agent waits for you.

## [0.5.0] — 2026-09-30
### Added
- `SessionStart` hook → `p bind`: sessions started by hand, via `/resume` or `/clear` are bound too.

## [0.4.0] — 2026-09-27
### Added
- Projects live in `projects.tsv`; `p add` / `p remove`.

## [0.3.0] — 2026-09-23
### Changed
- `c` merged into `p` (`p claude`; `c` is a symlink).
### Added
- F2 opens a window with claude, F8 a plain shell, F5 renames a window with its binding.
- `exit` in a window forgets it (bash `EXIT` trap), SIGHUP does not.

## [0.2.0] — 2026-09-19
### Added
- Agent state glyphs ◐ ! ✓ via Claude Code hooks (`agent-status`).

## [0.1.0] — 2026-09-13
### Added
- Session manifest binding project/window to a Claude Code session id; `c` wrapper.
- `p restore` and `p forget`.

## [0.0.1] — 2026-09-10
### Added
- `p`: tmux project menu on F1 and function-key bindings.

[1.1.1]: https://github.com/tarpedo/claude-code-projects/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/tarpedo/claude-code-projects/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.6.0...v1.0.0
[0.6.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/tarpedo/claude-code-projects/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/tarpedo/claude-code-projects/releases/tag/v0.0.1
