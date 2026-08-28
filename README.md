<!-- SPDX-License-Identifier: MIT -->

# swiftdev — portable, disposable Swift development environment

`swiftdev` is a member of the [`langdev`](../../dockerfile/langdev) suite:
a complete, batteries-included Swift toolchain inside a container you can
**spin up and throw away in seconds** — on any machine with Docker or
Podman (Linux, macOS, Windows/WSL2).

It ships the official, pinned Swift toolchain (`swiftc`, `swift`,
`sourcekit-lsp`, `swift-format`) inside the **langdev dotfiles
foundation**: the developer environment (shell, editor, tmux) is the
**user's own chezmoi-managed dotfiles**, cloned and `chezmoi apply`'d at
build time (latest by default; pin with `DOTFILES_REF`). swiftdev adds
only one Neovim LSP drop-in (`nvim/plugins.local/lang.lua`, wiring
SourceKit-LSP via `nvim-lspconfig`) and one login-shell env fragment. The
Neovim plugin set is baked headless at build time, so **no network is
needed on first launch**.

- **tmux is installed and loaded by default**: the entrypoint attaches to
  (or creates) a persistent `langdev` tmux session for interactive
  shells. Opt out with `LANGDEV_NO_TMUX=1`.
- The **dotfiles' Neovim config is authoritative**; swiftdev only drops
  `nvim/plugins.local/lang.lua` into it (auto-imported via the config's
  `plugins.local` convention) to wire the Swift LSP.

## Quick start

```sh
make up                       # build (if needed) + drop into a dev shell
make run CMD="swift test"     # one-shot command in a fresh container
make trash                    # remove the image + dangling build cache
```

Your code is the **only** bind mount, at `/work`. Everything else is
ephemeral (read-only rootfs + tmpfs), so a container is truly disposable.

## Architectural deviation: glibc base, not Alpine

> **Why swiftdev does not use the suite's Alpine base.**
> Every other `langdev` image builds on Alpine (musl libc) for a tiny,
> hardened runtime. **Swift has no officially supported musl/Alpine
> toolchain** — the Swift project ships prebuilt toolchains and container
> images only for glibc distributions (Ubuntu, Debian, Amazon Linux,
> RHEL UBI). A musl build of Swift is not officially supported, so the
> Alpine base used by the rest of the suite **cannot** work here.
>
> swiftdev therefore builds on the **official Swift image**,
> `swift:6.3.3-slim`, which is **Ubuntu 24.04 "noble" (glibc)**, pinned
> **by digest**. Consuming the official image directly means the Swift
> toolchain is already GPG-verified upstream at image-build time against
> the Swift release signing key
> (`52BB7E3DE28A71BE22EC05FFEF80A866B47A981F`) — we do not re-fetch or
> re-verify a toolchain tarball.
>
> Everything else is unchanged: swiftdev **reuses every distro-agnostic
> common asset verbatim** (`common/bootstrap-dotfiles.sh`,
> `common/entrypoint.sh`), the identical hardened
> `compose.yaml`/`Makefile`/CI, the same non-root, read-only,
> `cap_drop: [ALL]`, `no-new-privileges` posture, and the same
> pinned-and-checksummed input discipline. The foundation's Alpine
> `env-build` and `base` stages are **translated to `apt-get
> --no-install-recommends`** (apt lists cleaned in the same layer) with
> identical behaviour. Two tools that Alpine gets from `apk` are handled
> specially on glibc:
>
> - **Neovim** — Ubuntu's packaged Neovim is too old for the dotfiles'
>   config, so a **pinned, sha256-verified release tarball** is installed
>   into `/opt/nvim`.
> - **chezmoi** — not in the default Debian/Ubuntu repos, so the official
>   **pinned, sha256-verified release archive** is installed into
>   `/usr/local/bin` (no `curl | sh`).
>
> `zoxide` is installed via `apt` from the noble `universe` repo (enabled
> in the official Swift/Ubuntu base). Debian's `fd-find`/`bat` binaries
> (`fdfind`/`batcat`) are symlinked to the conventional `fd`/`bat` names.

## What's inside (pinned)

| Component | Version | How it's pinned |
|---|---|---|
| Swift base image | `swift:6.3.3-slim` (Ubuntu 24.04) | by digest `sha256:c2b5f7c9…8b7ecd` (multi-arch index: amd64 + arm64) |
| Swift toolchain | `6.3.3` | baked into the digest-pinned base; GPG-verified upstream |
| SourceKit-LSP | (with `6.3.3`) | ships with the toolchain, on `PATH` at `/usr/bin` |
| swift-format | (with `6.3.3`) | bundled with the toolchain (`swift format`) |
| Neovim | `0.12.5` | GitHub release tarball, sha256-verified (amd64 + arm64) |
| chezmoi | `2.72.0` | GitHub release archive, sha256-verified (amd64 + arm64) |
| Dotfiles | `DOTFILES_REF` (default `main`) | git ref of the user's dotfiles repo; recorded commit in `~/.dotfiles.commit` |
| ripgrep / fd-find / fzf / bat / zoxide / tmux | (Ubuntu 24.04 apt) | from the digest-locked base's apt repos (`zoxide` via `universe`) |
| Neovim plugins | — | baked headless from the dotfiles' own `lazy-lock.json` |

Pinned sha256 for the Neovim tarball:

- `nvim-linux-x86_64.tar.gz` → `bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875`
- `nvim-linux-arm64.tar.gz` → `1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725`

Pinned sha256 for the chezmoi release archive
(`chezmoi_2.72.0_linux_<arch>.tar.gz`):

- `amd64` → `0d6665b96c527d57fdc562bf19e808f80f48c2d977062c03e3e65c6b09eafbce`
- `arm64` → `e79a27621256390f03166d3965e6a1946f983a096c4d90f02c43d2aa5b563728`

Unlike the Alpine members of the suite, there is **no separate `toolchain`
stage** to copy a relocatable prefix from — the toolchain *is* the base
image. The `env-build` stage clones + `chezmoi apply`s the dotfiles and
bakes the editor + plugins so the runtime image needs no network on first
launch; build tools (`build-essential`, `cmake`, `chezmoi`) live only in
that stage and never reach the final image.

> **Neovim plugin pinning:** the plugin set is baked from the **dotfiles'
> own `lazy-lock.json`** (`Lazy! restore` → `sync`), so reproducibility of
> the editor tracks the dotfiles ref. Pin `DOTFILES_REF` to a tag/commit
> for a fully reproducible build.

## Make targets

| Target | Description |
|---|---|
| `make up` / `make shell` | Build then start an interactive dev shell |
| `make run CMD="…"` | Run a one-shot command in a fresh container |
| `make build` | Build the image for the host arch |
| `make buildx` | Build a multi-arch image (`linux/amd64,linux/arm64`) |
| `make trash` | Remove the image and dangling build cache |
| `make lint` | `hadolint` the Containerfile + `shellcheck` the scripts |
| `make scan` | Trivy vulnerability scan (HIGH/CRITICAL) of the built image |
| `make sbom` | Generate a CycloneDX SBOM (`sbom.cdx.json`) via syft |
| `make sync-common` | Refresh `common/` from the langdev source |

The `Makefile` auto-detects `docker` or `podman` (adding `:Z` SELinux
mount flags for Podman) so the same commands work with either engine.

## Aliases

Language-agnostic aliases come from the **user's own dotfiles**
(`chezmoi apply`'d at build time). Swift-specific aliases come from
`dotfiles.d/swift.sh`, installed to `/etc/profile.d/swift.sh`
(root-owned, `0644`) so it loads for login shells **without** polluting
the pristine chezmoi dotfiles.

### Swift (`dotfiles.d/swift.sh` → `/etc/profile.d/swift.sh`)

| Alias | Expands to |
|---|---|
| `sb` | `swift build` |
| `sr` | `swift run` |
| `st` | `swift test` |
| `sfmt` | `swift format` |
| `sfmti` | `swift format --in-place` |

`dotfiles.d/swift.sh` keeps `/usr/bin` (the toolchain prefix) on `PATH`
and defines aliases **only** for tools actually installed in the image.
It does **not** propagate any host `PATH`.

## Neovim

- The **user's dotfiles Neovim config is authoritative** — cloned and
  `chezmoi apply`'d at build time. swiftdev does not ship its own editor
  config beyond the one LSP drop-in below.
- Installed from a **pinned, sha256-verified Neovim release tarball**
  (Ubuntu's packaged Neovim is too old for modern configs), into
  `/opt/nvim` on `PATH`.
- Swift is wired by `nvim/plugins.local/lang.lua`, dropped into the
  dotfiles' nvim at `lua/plugins.local/` (auto-imported via the config's
  `plugins.local` convention). It configures `nvim-lspconfig`'s
  `sourcekit` server, pointed at the pre-installed `sourcekit-lsp` on
  `PATH`; the workspace root and Swift filetypes come from lspconfig's
  built-in `sourcekit` defaults.
- Treesitter grammar `swift` is added on top of the dotfiles' set.
- The LSP is installed at build time and plugins are baked headless, so
  **first launch needs no network** and the image stays reproducible.

## Security posture

Enforced by `compose.yaml` (and mirrored in `make run`/`make shell`):

- Runs as non-root `dev` (UID/GID `1000`); no `sudo`, no setuid binaries
  (setuid/setgid bits stripped at build; `/tmp` is `1777`, sticky — not `777`).
- `read_only: true` root filesystem, with tmpfs for `/tmp`,
  `/home/dev/.cache` (Swift's Clang/module cache), `/home/dev/.local/state`.
- `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`, `init: true`.
- Resource limits: `pids_limit: 512`, `mem_limit: 4g` (Swift/LLVM builds
  are memory-hungry), `cpus: 2.0`.
- The **only** bind mount is your project directory at `/work`; SwiftPM
  build output lands in `./.build` there.
- Base image pinned **by digest**; Swift toolchain GPG-verified upstream;
  Neovim tarball sha256-verified per arch. No `curl | sh`.
- No `.env` is committed or `COPY`'d into an image — secrets are
  runtime-only via compose `env_file`. `.env` is gitignored **and**
  dockerignored. `swiftdev` needs no secrets to build or run.

## Portability

One OCI `Containerfile` builds with `docker build`, `podman build`,
`buildah`, or `nerdctl`, for **`linux/amd64` and `linux/arm64`** (both
architectures are provided by the official Swift image and the pinned
Neovim release). No host-path assumptions beyond the `/work` bind mount.
Runs on Linux, macOS, and Windows/WSL2 hosts.

## CI

`.github/workflows/ci.yml` gates every change with `hadolint`,
`shellcheck`, a Docker build, a Trivy scan (fails on HIGH/CRITICAL), and
uploads a CycloneDX SBOM artifact.

## License

MIT — see [`LICENSE`](LICENSE).
