<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-08-29

### Added

- **Model Context Protocol (MCP) Server Suite.**
  - Added `common/mcp-server.sh` implementing JSON-RPC 2.0 stdio transport exposing workspace tools (`list_files`, `read_file`, `git_status`, `git_diff`, `run_tests`, `run_command`) to AI coding agents.
  - Added `common/mcp.json` configuration template for Claude Code, Cursor, and Aider.
- **AI Context Packing (`ai-pack`).**
  - Added `common/ai-pack.sh` for fast, token-efficient XML and Markdown codebase bundling respecting `.gitignore`.
- **Local LLM Routing.**
  - Added automatic resolution for local Ollama instances (`http://host.containers.internal:11434`).
- **Bats Unit Tests.**
  - Added `test/mcp.bats` and `test/ai-pack.bats`.

## [0.0.2] - 2026-08-29

### Added

- **Remote & Mobile Web Access.**
  - `make web` and `make web-auth` targets using `ttyd` for browser-based access on iPads and mobile devices over WebSocket/SSL.
  - `make mosh` for UDP-based roaming mobile shell sessions that survive connection drops.
- **Diagnostic CLI (`make doctor`).**
  - Added `common/doctor.sh` to probe host engines, architecture, cgroups, kernel security, and clipboard readiness.
- **Universal Clipboard (OSC 52).**
  - Added `set -s set-clipboard on` in `common/tmux.conf` for seamless copy-paste to host/mobile clipboards.
- **TUI Popups.**
  - Added floating TMUX popups for Lazygit (`Prefix + g`) and Lazydocker (`Prefix + d`).
- **VS Code IDE Grid & Parallel Task Worktrees.**
  - Added `common/tmux-ide.sh` (`Prefix + i`) and `common/muxtree.sh` (`Prefix + m`).

## [0.0.1] - 2026-08-29

The initial `swiftdev` image: a complete, disposable Swift toolchain
built on the [`langdev`](https://github.com/sebastienrousseau/langdev)
hardened core, booting the developer's own chezmoi-managed dotfiles.

### Added

- **Swift toolchain.** Swift `6.3.3` (`swiftc`, `swift`,
  `sourcekit-lsp`, `swift format`) from the official
  `swift:6.3.3-slim` image (Ubuntu 24.04 "noble", glibc), pinned **by
  digest** and GPG-verified upstream against the Swift release signing
  key.
- **Editor wiring.** One Neovim `plugins.local/lang.lua` drop-in
  configuring `nvim-lspconfig`'s `sourcekit` server and the `swift`
  Treesitter grammar; plugins baked headless at build time so first
  launch needs no network.
- **Login-shell fragment.** `dotfiles.d/swift.sh`, installed to
  `/etc/profile.d/swift.sh`, adds Swift aliases (`sb`, `sr`, `st`,
  `sfmt`, `sfmti`) without polluting the user's dotfiles.
- **Security posture, on by default.** Non-root `dev` (UID/GID 1000);
  `cap_drop: [ALL]`; `no-new-privileges`; read-only root filesystem
  with `tmpfs` for writable state; `pids_limit: 512`, `mem_limit: 4g`
  (Swift/LLVM builds are memory-hungry); no committed or baked-in
  secrets.
- **`make` lifecycle.** `build`, `buildx` (multi-arch: `linux/amd64`,
  `linux/arm64`), `up`/`shell`, `run`, `lint`, `scan`, `sbom`,
  `trash`, and `sync-common`.
- **CI gates.** `hadolint`, `shellcheck`, a Docker build, a Trivy image
  scan (fail on HIGH/CRITICAL), and a CycloneDX SBOM artifact.

### Portability

- **Deliberate glibc base, not the suite's Alpine.** Swift has **no
  officially supported musl/Alpine toolchain** — the Swift project
  ships prebuilt toolchains and images only for glibc distributions —
  so `swiftdev` builds on the official `swift:6.3.3-slim` (Ubuntu
  24.04, glibc) image instead of the suite's Alpine base. Every
  distro-agnostic common asset (`common/bootstrap-dotfiles.sh`,
  `common/entrypoint.sh`), the hardened `compose.yaml`/`Makefile`/CI,
  and the pinned-and-checksummed input discipline are reused verbatim.
  Two tools Alpine gets from `apk` are installed on glibc as **pinned,
  sha256-verified release archives**: Neovim `0.12.5` (Ubuntu's
  packaged Neovim is too old) into `/opt/nvim`, and chezmoi `2.72.0`
  (absent from the default Debian/Ubuntu repos) into `/usr/local/bin`
  — no `curl | sh`.

### Documentation

- README rewritten to the langdev [`STYLE.md`](https://github.com/sebastienrousseau/langdev/blob/main/STYLE.md)
  house style, with an honest "When not to use swiftdev" section and a
  frank account of the glibc-base deviation.
- Community docs vendored from the langdev suite:
  [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md),
  [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md),
  [`SUPPORT.md`](SUPPORT.md), [`GOVERNANCE.md`](GOVERNANCE.md).
- `.github/` scaffolding: `CODEOWNERS`, `FUNDING.yml`, `dependabot.yml`,
  a pull-request template, and issue forms.

### Licensing

- Relicensed from single MIT to **dual `Apache-2.0 OR MIT`**. Added
  `LICENSE-APACHE` and `LICENSE-MIT`, removed the single `LICENSE`
  file, and applied `SPDX-License-Identifier: Apache-2.0 OR MIT`
  headers across all non-vendored sources.

[Unreleased]: https://github.com/sebastienrousseau/swiftdev/commits/main
