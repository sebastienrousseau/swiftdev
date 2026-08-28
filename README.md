<!-- SPDX-License-Identifier: MIT -->

# swiftdev — portable, disposable Swift development environment

`swiftdev` is a member of the [`langdev`](../../dockerfile/langdev) suite:
a complete, batteries-included Swift toolchain inside a container you can
**spin up and throw away in seconds** — on any machine with Docker or
Podman (Linux, macOS, Windows/WSL2).

It ships the official, pinned Swift toolchain (`swiftc`, `swift`,
`sourcekit-lsp`, `swift-format`) plus a pre-configured Neovim (LazyVim
with SourceKit-LSP wired via `nvim-lspconfig`, pointed at the build-time
`sourcekit-lsp`). No network is needed on first launch.

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
> common asset** (dotfiles, Neovim config, entrypoint), the identical
> hardened `compose.yaml`/`Makefile`/CI, the same non-root, read-only,
> `cap_drop: [ALL]`, `no-new-privileges` posture, and the same
> pinned-and-checksummed input discipline. Where the suite template uses
> `apk`, swiftdev uses `apt-get --no-install-recommends` with apt lists
> cleaned in the same layer.

## What's inside (pinned)

| Component | Version | How it's pinned |
|---|---|---|
| Swift base image | `swift:6.3.3-slim` (Ubuntu 24.04) | by digest `sha256:c2b5f7c9…8b7ecd` (multi-arch index: amd64 + arm64) |
| Swift toolchain | `6.3.3` | baked into the digest-pinned base; GPG-verified upstream |
| SourceKit-LSP | (with `6.3.3`) | ships with the toolchain, on `PATH` at `/usr/bin` |
| swift-format | (with `6.3.3`) | bundled with the toolchain (`swift format`) |
| Neovim | `0.12.5` | GitHub release tarball, sha256-verified (amd64 + arm64) |
| ripgrep / fd-find | (Ubuntu 24.04 apt) | from the digest-locked base's apt repos |
| Neovim plugins | — | `nvim/lazy-lock.json` (regenerate with `make lock`/CI) |

Pinned sha256 for the Neovim tarball:

- `nvim-linux-x86_64.tar.gz` → `bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875`
- `nvim-linux-arm64.tar.gz` → `1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725`

Unlike the Alpine members of the suite, there is **no separate `toolchain`
stage** to copy a relocatable prefix from — the toolchain *is* the base
image. The `nvim-build` stage bakes the editor + plugins so the runtime
image needs no network on first launch; build tools (`build-essential`,
`cmake`) live only in that stage and never reach the final image.

> **Neovim lockfile bootstrap:** `nvim/lazy-lock.json` is committed as
> `{}` to bootstrap the build. The first CI image build (or a local
> `nvim --headless +"Lazy! sync"`) regenerates the fully pinned lockfile;
> commit the result to freeze the exact plugin set.

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
| `make lock` | Regenerate `nvim/lazy-lock.json` from the built image |
| `make sync-common` | Refresh `common/` from the langdev source |

The `Makefile` auto-detects `docker` or `podman` (adding `:Z` SELinux
mount flags for Podman) so the same commands work with either engine.

## Aliases

Provided by `common/dotfiles/bash_aliases` (language-agnostic) and
`dotfiles.d/swift.sh` (Swift-specific), both sourced by the interactive
shell.

### Swift (`dotfiles.d/swift.sh`)

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

- LazyVim starter, pinned by commit and baked in at build time.
- Installed from a **pinned, sha256-verified Neovim release tarball**
  (Ubuntu's packaged Neovim is too old for LazyVim), into `/opt/nvim` on
  `PATH`.
- Swift is configured in `nvim/plugins/lang.lua` via `nvim-lspconfig`'s
  `sourcekit` server, pointed at the pre-installed `sourcekit-lsp` on
  `PATH`; the workspace root is anchored on `Package.swift`.
- Treesitter grammar `swift` is added on top of the common set.
- **Mason is intentionally disabled** — the LSP is installed at build
  time, so first launch needs no network and the image stays reproducible.

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
