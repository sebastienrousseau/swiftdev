<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

<p align="center">
  <img src="https://cloudcdn.pro/swiftdev/v1/logos/swiftdev.svg" alt="swiftdev logo" width="128" />
</p>

<h1 align="center">swiftdev</h1>

<p align="center">
  A portable, disposable Swift 6.3.3 development container that builds
  with <b>both</b> Docker and Podman and boots the developer's own
  chezmoi-managed dotfiles.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/swiftdev/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/swiftdev/ci.yml?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue?style=for-the-badge" alt="License: Apache-2.0 OR MIT" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/swiftdev"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/swiftdev?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" /></a>
  <a href="#portability"><img src="https://img.shields.io/badge/engines-docker%20%7C%20podman-1d63ed?style=for-the-badge&logo=docker" alt="Engines: Docker or Podman" /></a>
  <a href="#portability"><img src="https://img.shields.io/badge/arch-amd64%20%C2%B7%20arm64-555?style=for-the-badge" alt="Architectures: amd64, arm64" /></a>
</p>

---

## Contents

**Getting started**

- [Quick start](#quick-start) — clone, `make up`, and you are in a dev shell
- [Why this approach?](#why-this-approach) — the choices that shape the image

**What you get**

- [What's inside](#whats-inside) — the pinned toolchain, exactly
- [The developer environment IS your dotfiles](#the-developer-environment-is-your-dotfiles) — no synthetic config, tmux loaded by default

**Operational**

- [Security model](#security-model) — the container threat model and controls
- [Portability](#portability) — engines, architectures, host assumptions
- [When not to use swiftdev](#when-not-to-use-swiftdev) — limitations, stated plainly
- [Development](#development) — `make` targets, tests, lint, scan, SBOM, CI
- [Documentation](#documentation) — community docs and the house style
- [License](#license)

---

## Quick start

`swiftdev` is standalone. Clone it, and one command gets you an
interactive, hardened Swift shell in a fresh container:

```sh
git clone https://github.com/sebastienrousseau/swiftdev.git
cd swiftdev
make up                       # build (if needed) + interactive dev shell
```

Other everyday commands:

```sh
make run CMD="swift test"     # one-shot command in a fresh container
make trash                    # remove the image + dangling build cache
```

Your project directory is the **only** bind mount, at `/work`; SwiftPM
build output lands in `./.build` there. Everything else is ephemeral
(read-only rootfs + tmpfs), so a container is genuinely disposable. No
registry pull and no network are needed on first launch — the image,
including the Neovim plugin set, is built entirely from the repo you
cloned.

---

## Why this approach?

`swiftdev` is a member of the
[`langdev`](https://github.com/sebastienrousseau/langdev) suite: a
complete Swift toolchain in a container you spin up and throw away in
seconds. Four choices, in priority order, shape the image:

1. **Secure by default, not by opt-in.** The container runs as a
   non-root `dev` user (UID/GID 1000) with **all Linux capabilities
   dropped**, `no-new-privileges`, and a **read-only root filesystem**;
   writable state is confined to explicit `tmpfs` mounts. This is the
   default `make up` posture, not a hardened variant you have to
   remember to select. The threat model is [documented](SECURITY.md),
   not implied.

2. **Complete, not a kitchen sink.** The image ships only what a Swift
   developer actually needs — the toolchain, SourceKit-LSP,
   `swift format`, Neovim, and a shell — measured against a real
   workflow: you can edit, build, test, and debug without reaching
   outside the container.

3. **Portable and disposable.** One OCI `Containerfile` builds with
   Docker, Podman, Buildah, and nerdctl. The `Makefile` auto-detects the
   engine and adjusts flags (SELinux `:Z` mounts, userns) accordingly.
   Images are multi-arch (`linux/amd64`, `linux/arm64`). The only bind
   mount is your project at `/work`, and `make trash` leaves nothing
   behind.

4. **Reliable and reproducible.** The base image is pinned **by
   digest**, the Swift toolchain is GPG-verified upstream, and every
   downloaded binary is **checksum-verified** — there is no `curl | sh`
   anywhere in the build. Pin `DOTFILES_REF` to a tag or commit and the
   build is reproducible.

Where `swiftdev` deviates from the suite — a glibc base instead of
Alpine — it does so out of necessity, and says exactly why in
[Portability](#portability). Everything language-agnostic is otherwise
**vendored** from the langdev core under `common/` and refreshed with
`make sync-common`, so swiftdev is a complete, auditable unit on its
own.

---

## What's inside

Everything is pinned. The base image is pinned by digest; the Swift
toolchain comes GPG-verified from upstream inside that digest; Neovim
and chezmoi are installed from sha256-verified release archives.

| Component | Version | How it's pinned |
|---|---|---|
| Swift base image | `swift:6.3.3-slim` (Ubuntu 24.04 "noble", glibc) | by digest `sha256:c2b5f7c9…8b7ecd` (multi-arch index: amd64 + arm64) |
| Swift toolchain | `6.3.3` (`swiftc`, `swift`) | baked into the digest-pinned base; GPG-verified upstream against the Swift release signing key `52BB7E3DE28A71BE22EC05FFEF80A866B47A981F` |
| SourceKit-LSP | ships with `6.3.3` | on `PATH` at `/usr/bin` |
| swift-format | ships with `6.3.3` | bundled with the toolchain (`swift format`) |
| Neovim | `0.12.5` | GitHub release tarball, sha256-verified per arch, into `/opt/nvim` |
| chezmoi | `2.72.0` | GitHub release archive, sha256-verified per arch, into `/usr/local/bin` |
| Dotfiles | `DOTFILES_REF` (default `main`) | git ref of the user's dotfiles repo; recorded commit in `~/.dotfiles.commit` |
| ripgrep / fd-find / fzf / bat / zoxide / tmux | Ubuntu 24.04 apt | from the digest-locked base's apt repos (`zoxide` via `universe`) |
| Neovim plugins | — | baked headless from the dotfiles' own `lazy-lock.json` |

Pinned sha256 for the Neovim tarball:

- `nvim-linux-x86_64.tar.gz` → `bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875`
- `nvim-linux-arm64.tar.gz` → `1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725`

Pinned sha256 for the chezmoi archive
(`chezmoi_2.72.0_linux_<arch>.tar.gz`):

- `amd64` → `0d6665b96c527d57fdc562bf19e808f80f48c2d977062c03e3e65c6b09eafbce`
- `arm64` → `e79a27621256390f03166d3965e6a1946f983a096c4d90f02c43d2aa5b563728`

Unlike the Alpine members of the suite, there is **no separate
`toolchain` stage** to copy a relocatable prefix from — the toolchain
*is* the base image. An `env-build` stage clones and `chezmoi apply`s
the dotfiles and bakes the editor plus its plugins, so the runtime
image needs no network on first launch; build tools
(`build-essential`, `cmake`, `chezmoi`) live only in that stage and
never reach the final image.

Swift/LLVM builds are memory-hungry, so the default `mem_limit` is
`4g` (see [Security model](#security-model)).

---

## The developer environment IS your dotfiles

`swiftdev` does **not** ship a synthetic shell or editor config. At
build time the image clones the user's chezmoi-managed **dotfiles
repo** and runs `chezmoi apply`, so the container has the *real*
bashrc, aliases, tmux config, and Neovim setup — **always the latest**
by default. Pin `DOTFILES_REF` to a tag or commit for a reproducible
build; the exact commit bundled is recorded at `~/.dotfiles.commit`.

- **tmux is installed and loaded by default.** An interactive shell
  attaches to (or creates) a persistent `langdev` tmux session, so panes
  and windows survive detach. Opt out with `LANGDEV_NO_TMUX=1`.
- **The dotfiles' Neovim config is authoritative.** swiftdev drops
  exactly one `nvim/plugins.local/lang.lua` spec into the config's
  `plugins.local/` directory (auto-imported via that convention), so it
  composes with the rest of your setup untouched.
- **LSP via `nvim-lspconfig`.** Swift is wired through
  `nvim-lspconfig`'s `sourcekit` server against the pre-installed
  `sourcekit-lsp` on `PATH` — no Mason, no network on first launch.
  Workspace root and Swift filetypes come from lspconfig's built-in
  `sourcekit` defaults, and the `swift` Treesitter grammar is added on
  top of your set.
- **Baked, offline-ready.** The full plugin set (yours plus this spec)
  is baked headless at build time from your dotfiles'
  `nvim/lazy-lock.json`, so the container is reproducible and needs no
  network on first launch.

Swift-specific aliases live in `dotfiles.d/swift.sh`, installed to
`/etc/profile.d/swift.sh` (root-owned, `0644`) so they load for login
shells **without** polluting the pristine chezmoi dotfiles: `sb`
(`swift build`), `sr` (`swift run`), `st` (`swift test`), `sfmt`
(`swift format`), `sfmti` (`swift format --in-place`).

---

## Security model

The full threat model and the private disclosure process are in
[`SECURITY.md`](SECURITY.md). Enforced by `compose.yaml` and mirrored in
`make run` / `make shell`:

- **Non-root.** Runs as `dev` (UID/GID 1000); no `sudo`, no setuid
  binaries — setuid/setgid bits are stripped at build, and `/tmp` is
  `1777`, sticky — not `777`.
- **Least privilege at runtime.** `cap_drop: [ALL]`,
  `security_opt: [no-new-privileges:true]`, `read_only: true` (with
  `tmpfs` for `/tmp`, `/home/dev/.cache` (Swift's Clang/module cache),
  and `/home/dev/.local/state`), and `init: true`.
- **Resource limits.** `pids_limit: 512`, `mem_limit: 4g` (Swift/LLVM
  builds are memory-hungry), `cpus: 2.0`.
- **Pinned, checksummed inputs.** Base image pinned **by digest**; the
  Swift toolchain GPG-verified upstream; the Neovim and chezmoi
  archives sha256-verified per arch. Never `curl | sh`.
- **No committed secrets.** No `.env` is committed or `COPY`'d into an
  image — secrets are runtime-only via compose `env_file`. `.env` is
  gitignored **and** dockerignored. `swiftdev` needs no secrets to build
  or run.
- **One bind mount.** The only bind mount is your project directory at
  `/work`; SwiftPM output lands in `./.build` there.
- **CI gates every change.** `hadolint`, `shellcheck`, a Docker build,
  and a Trivy image scan (fail on HIGH/CRITICAL) run on every push and
  pull request; a CycloneDX SBOM is uploaded as an artifact.

Report a vulnerability privately — see [`SECURITY.md`](SECURITY.md). Do
not open a public issue.

---

## Portability

- **One `Containerfile` (OCI).** `docker build`, `podman build`,
  `buildah`, and `nerdctl` all work from the same file, for
  `linux/amd64` and `linux/arm64` (both architectures are provided by
  the official Swift image and the pinned Neovim release).
- **Engine autodetection.** The `Makefile` detects `docker` or `podman`
  and adjusts flags (SELinux `:Z` mounts) accordingly.
- **Multi-arch.** Images build for `linux/amd64` and `linux/arm64` via
  `docker buildx` / `podman --platform`.
- **No host assumptions.** The only bind mount is your project directory
  at `/work`. Runs on Linux, macOS, and Windows/WSL2 hosts.

### The glibc-base deviation (stated honestly)

Every other `langdev` image builds on Alpine (musl libc) for a tiny,
hardened runtime. `swiftdev` does not, and the reason is a hard
constraint rather than a preference:

- **Swift has no officially supported musl/Alpine toolchain.** The
  Swift project ships prebuilt toolchains and container images only
  for glibc distributions (Ubuntu, Debian, Amazon Linux, RHEL UBI). A
  musl build of Swift is not officially supported, so the Alpine base
  used by the rest of the suite **cannot** work here. This is a
  limitation of the upstream ecosystem, not something `swiftdev` can
  paper over.

`swiftdev` therefore builds on the **official Swift image**,
`swift:6.3.3-slim`, which is **Ubuntu 24.04 "noble" (glibc)**, pinned
**by digest**. Consuming the official image directly means the Swift
toolchain is already GPG-verified upstream at image-build time against
the Swift release signing key — `swiftdev` does not re-fetch or
re-verify a toolchain tarball.

Everything else is unchanged. `swiftdev` **reuses every
distro-agnostic common asset verbatim**
(`common/bootstrap-dotfiles.sh`, `common/entrypoint.sh`), the
identical hardened `compose.yaml` / `Makefile` / CI, the same
non-root, read-only, `cap_drop: [ALL]`, `no-new-privileges` posture,
and the same pinned-and-checksummed input discipline. The foundation's
Alpine `env-build` and `base` stages are **translated to
`apt-get --no-install-recommends`** (apt lists cleaned in the same
layer) with identical behaviour. Two tools that Alpine gets from `apk`
are handled specially on the Debian/Ubuntu base:

- **Neovim** — Ubuntu's packaged Neovim is too old for the dotfiles'
  config, so a **pinned, sha256-verified release tarball** is
  installed into `/opt/nvim`.
- **chezmoi** — not in the default Debian/Ubuntu repos, so the
  official **pinned, sha256-verified release archive** is installed
  into `/usr/local/bin` (no `curl | sh`).

`zoxide` is installed via `apt` from the noble `universe` repo
(enabled in the official Swift/Ubuntu base). Debian's `fd-find` /
`bat` binaries (`fdfind` / `batcat`) are symlinked to the conventional
`fd` / `bat` names.

---

## When not to use swiftdev

Stated plainly, so you can rule it out fast:

- **You need a production runtime image.** `swiftdev` builds a
  *development* environment — editor, LSP, test tooling, a shell. It is
  deliberately not a minimal production artifact; ship a separate,
  slimmer image for that.
- **You do not use chezmoi-managed dotfiles.** The environment *is* the
  user's dotfiles. Without a chezmoi dotfiles repo you lose the main
  point, though the hardening and toolchain layers still stand on their
  own.
- **You need a musl/Alpine or fully static Swift build.** The upstream
  Swift project does not officially support a musl toolchain, so
  `swiftdev` is glibc-based by necessity. If your target demands Alpine
  or static-musl Swift, this image cannot provide it.
- **You need GPU passthrough or host-device access.** The default
  posture drops all capabilities and forbids privilege escalation.
  Workloads that need device access require deliberate, documented
  relaxations that run against the grain of the design.
- **You are on a platform without Docker or Podman.** There is no
  VM-less fallback; swiftdev targets an OCI engine on Linux, macOS, or
  Windows/WSL2.

---

## Development

The `Makefile` exposes the full lifecycle and auto-detects `docker` or
`podman` (adding `:Z` SELinux mount flags for Podman), so the same
commands work with either engine:

```sh
make up          # build + interactive dev shell (alias: make shell)
make run CMD=…   # one-shot command in a fresh container
make build       # build the image for the host arch
make buildx      # multi-arch build (linux/amd64, linux/arm64)
make lint        # hadolint the Containerfile + shellcheck the scripts
make scan        # Trivy vulnerability scan (fail on HIGH/CRITICAL)
make sbom        # CycloneDX SBOM via syft
make trash       # remove the image and dangling build cache
make sync-common # refresh common/ from the langdev source
```

### Tests and coverage

The language-agnostic shell core — `common/bootstrap-dotfiles.sh` and
`common/entrypoint.sh` — is vendored verbatim from the
[`langdev`](https://github.com/sebastienrousseau/langdev) core and
refreshed with `make sync-common`. That core is unit-tested with
[bats-core](https://github.com/bats-core/bats-core) under
[kcov](https://github.com/SimonKagstrom/kcov) in the langdev repo, whose
`make test` / `make coverage` gate **fails below 95 % line coverage**.
The tests are hermetic — `git`, `chezmoi`, `nvim`, `tmux`, and `rsync`
are test doubles on a closed `PATH`, so no network or container is
needed. The suite and its coverage gate are documented in
[langdev's `test/README.md`](https://github.com/sebastienrousseau/langdev/blob/main/test/README.md).

### CI and security workflows

This repo's [`.github/workflows/ci.yml`](.github/workflows/ci.yml) gates
every push and pull request with `hadolint`, `shellcheck`, a Docker
build, a Trivy image scan (fail on HIGH/CRITICAL), and a CycloneDX SBOM
artifact. The suite's OpenSSF hardening workflows are maintained in the
langdev core and provisioned across the suite from
[`templates/github-workflows/`](https://github.com/sebastienrousseau/langdev/tree/main/templates/github-workflows):

| Workflow | What it gates |
|---|---|
| `ci.yml` | shellcheck, hadolint, Docker build, Trivy image scan (fail HIGH/CRITICAL), CycloneDX SBOM |
| `scorecard.yml` | OpenSSF Scorecard, results published + SARIF to code-scanning |
| `sast.yml` | ShellCheck + Trivy config + Checkov, SARIF → code-scanning |
| `dependency-review.yml` | dependency + action changes reviewed on every PR |

The OpenSSF Best-Practices self-assessment lives in the langdev core's
[`doc/CII-BEST-PRACTICES.md`](https://github.com/sebastienrousseau/langdev/blob/main/doc/CII-BEST-PRACTICES.md);
a maintainer can apply the branch-protection ruleset with langdev's
[`scripts/set-branch-protection.sh`](https://github.com/sebastienrousseau/langdev/blob/main/scripts/set-branch-protection.sh).

Contributions require signed commits and Conventional Commit messages —
see [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Documentation

| Document | What it covers |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The container workflow: build/test/lint/scan/sbom, signed commits, Conventional Commits. |
| [`SECURITY.md`](SECURITY.md) | The container threat model and the private disclosure process. |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community standards and enforcement. |
| [`GOVERNANCE.md`](GOVERNANCE.md) | Who decides what, and how the maintainer base is meant to grow. |
| [`SUPPORT.md`](SUPPORT.md) | Where to go for questions, bugs, and feature requests. |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes, Keep a Changelog format. |
| [langdev `doc/CII-BEST-PRACTICES.md`](https://github.com/sebastienrousseau/langdev/blob/main/doc/CII-BEST-PRACTICES.md) | OpenSSF Best-Practices self-assessment for the suite. |

swiftdev follows the langdev suite's house style — see
[`STYLE.md`](https://github.com/sebastienrousseau/langdev/blob/main/STYLE.md)
in the `langdev` core.

---

## License

Licensed under either of

- Apache License, Version 2.0 ([`LICENSE-APACHE`](LICENSE-APACHE))
- MIT license ([`LICENSE-MIT`](LICENSE-MIT))

at your option. The suite is dual-licensed `Apache-2.0 OR MIT`; every
non-vendored file carries an `SPDX-License-Identifier: Apache-2.0 OR MIT`
header.

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms
or conditions.
