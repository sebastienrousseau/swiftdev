# syntax=docker/dockerfile:1.9
# swiftdev Containerfile — OCI, builds with Docker AND Podman.
# SPDX-License-Identifier: Apache-2.0 OR MIT
#
# Multi-stage, hardened dev image for Swift, built on the langdev
# "dotfiles foundation": the developer environment (shell, editor, tmux)
# is the USER'S OWN chezmoi-managed dotfiles, cloned + applied at build
# time (latest by default; pin with DOTFILES_REF). swiftdev provides only
# the hardened base + the Swift toolchain (from the official image) + one
# Neovim LSP drop-in and one login-shell env fragment.
#
# ARCHITECTURAL DEVIATION (documented in README): the rest of the langdev
# suite builds on Alpine (musl) with `apk`. Swift has NO officially
# supported musl/Alpine toolchain, so swiftdev builds on the OFFICIAL
# Swift image, which is glibc (Ubuntu 24.04 "noble"). The foundation's
# Alpine `env-build` and `base` stages are TRANSLATED to `apt-get
# --no-install-recommends` (lists cleaned in the same layer) with identical
# behaviour. The identical security posture is preserved (non-root,
# read-only rootfs, cap-drop, no-new-privileges, pinned+checksummed
# inputs). Every distro-agnostic common asset is reused verbatim.
#
# The base is pinned BY DIGEST. The Swift toolchain (swiftc, swift,
# sourcekit-lsp, swift-format) is baked into this official image and its
# contents are GPG-verified upstream at image-build time against
# SWIFT_SIGNING_KEY 52BB7E3DE28A71BE22EC05FFEF80A866B47A981F — so we do NOT
# re-fetch a toolchain tarball here; we consume the verified, digest-pinned
# image directly. sourcekit-lsp / swift-format ship on PATH at /usr/bin.
ARG SWIFT_VERSION=6.3.3
# renovate: datasource=docker depName=swift
# Multi-arch index digest for `swift:6.3.3-slim` (linux/amd64 + linux/arm64).
ARG SWIFT_DIGEST=sha256:c2b5f7c9e24f4af9ff27bfb2bff4b04d5115673f06248fd2a7423819918b7ecd

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Dotfiles source — "always the latest" by default; pin a tag/commit for
# reproducible builds.
ARG DOTFILES_REPO=https://github.com/sebastienrousseau/dotfiles.git
ARG DOTFILES_REF=main

# Pinned Neovim release + per-arch sha256 (verified below). Bump together.
# Debian/Ubuntu's packaged Neovim is too old for modern LazyVim configs, so
# we install a PINNED, sha256-verified release tarball from GitHub instead.
ARG NEOVIM_VERSION=0.12.5
ARG NEOVIM_SHA256_AMD64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
ARG NEOVIM_SHA256_ARM64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725

# Pinned chezmoi release + per-arch sha256 (verified below). chezmoi is NOT
# in the default Debian/Ubuntu repos, so we install the official multi-arch
# release archive (which contains a single top-level `chezmoi` binary) and
# checksum-verify it — no `curl | sh`. Checksums are from the upstream
# chezmoi_<ver>_checksums.txt.
ARG CHEZMOI_VERSION=2.72.0
ARG CHEZMOI_SHA256_AMD64=0d6665b96c527d57fdc562bf19e808f80f48c2d977062c03e3e65c6b09eafbce
ARG CHEZMOI_SHA256_ARM64=e79a27621256390f03166d3965e6a1946f983a096c4d90f02c43d2aa5b563728

###############################################################################
# Stage: env-build  (COMMON — apply the user's dotfiles + bake nvim plugins)
#   Translated from the foundation's Alpine `env-build` stage to apt. Clones
#   and `chezmoi apply`s the user's dotfiles as the `dev` user, drops in the
#   Swift LSP spec, then bakes the full Neovim plugin set headless so the
#   runtime image needs NO network on first launch.
###############################################################################
FROM swift:${SWIFT_VERSION}-slim@${SWIFT_DIGEST} AS env-build
ARG USERNAME USER_UID USER_GID DOTFILES_REPO DOTFILES_REF
ARG NEOVIM_VERSION NEOVIM_SHA256_AMD64 NEOVIM_SHA256_ARM64
ARG CHEZMOI_VERSION CHEZMOI_SHA256_AMD64 CHEZMOI_SHA256_ARM64

# Tools needed to clone+apply dotfiles and compile/install nvim plugins.
# `build-essential` + `cmake` build treesitter grammars / fzf-native;
# `ripgrep` + `fd-find` back telescope; `fzf`/`bat` are dotfile expectations.
# These stay in this stage and never reach the runtime image.
# hadolint ignore=DL3008,DL3009
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      build-essential \
      cmake \
      ripgrep \
      fd-find \
      fzf \
      bat \
 && rm -rf /var/lib/apt/lists/*
# Debian/Ubuntu ship these under alternate names; expose the conventional ones.
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
 && ln -sf "$(command -v batcat)" /usr/local/bin/bat

# Pinned, sha256-verified Neovim tarball -> /opt/nvim (relocatable, on PATH).
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) nvimArch='x86_64'; nvimSha256="${NEOVIM_SHA256_AMD64}" ;; \
      arm64) nvimArch='arm64';  nvimSha256="${NEOVIM_SHA256_ARM64}" ;; \
      *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    url="https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-${nvimArch}.tar.gz"; \
    curl -fsSL "$url" -o /tmp/nvim.tar.gz; \
    echo "${nvimSha256}  /tmp/nvim.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/nvim.tar.gz -C /opt; \
    mv "/opt/nvim-linux-${nvimArch}" /opt/nvim; \
    rm -f /tmp/nvim.tar.gz; \
    /opt/nvim/bin/nvim --version

# Pinned, sha256-verified chezmoi (official release archive -> /usr/local/bin).
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) czSha256="${CHEZMOI_SHA256_AMD64}" ;; \
      arm64) czSha256="${CHEZMOI_SHA256_ARM64}" ;; \
      *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_linux_${arch}.tar.gz"; \
    curl -fsSL "$url" -o /tmp/chezmoi.tar.gz; \
    echo "${czSha256}  /tmp/chezmoi.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/chezmoi.tar.gz -C /tmp chezmoi; \
    install -m 0755 /tmp/chezmoi /usr/local/bin/chezmoi; \
    rm -f /tmp/chezmoi.tar.gz /tmp/chezmoi; \
    chezmoi --version

ENV PATH=/opt/nvim/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Non-root user with a real home (Debian/Ubuntu: groupadd/useradd, not adduser).
RUN groupadd -g "${USER_GID}" "${USERNAME}" \
 && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"

# Distro-agnostic bootstrap script (clones + chezmoi-applies the dotfiles).
COPY --chown=${USER_UID}:${USER_GID} common/bootstrap-dotfiles.sh /usr/local/bin/langdev-bootstrap-dotfiles
RUN chmod 0755 /usr/local/bin/langdev-bootstrap-dotfiles

USER ${USERNAME}
ENV HOME=/home/${USERNAME} \
    XDG_CONFIG_HOME=/home/${USERNAME}/.config \
    XDG_DATA_HOME=/home/${USERNAME}/.local/share \
    XDG_STATE_HOME=/home/${USERNAME}/.local/state \
    XDG_CACHE_HOME=/home/${USERNAME}/.cache

# 1) Clone + chezmoi-apply the user's dotfiles (brings bashrc, tmux, nvim…).
RUN DOTFILES_REPO="${DOTFILES_REPO}" DOTFILES_REF="${DOTFILES_REF}" \
      langdev-bootstrap-dotfiles

# 2) Drop the Swift LSP spec into the dotfiles' nvim (auto-imported via the
#    config's `plugins.local`), then bake the full plugin set headless so the
#    runtime needs no network on first launch. The dotfiles bring their own
#    lazy-lock.json; `Lazy! restore` pins to it, then sync + treesitter.
COPY --chown=${USER_UID}:${USER_GID} nvim/plugins.local/ /home/${USERNAME}/.config/nvim/lua/plugins.local/
RUN nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5 || true \
 && nvim --headless "+Lazy! sync"    +qa 2>&1 | tail -n 5 || true \
 && nvim --headless "+TSUpdateSync"  +qa 2>&1 | tail -n 5 || true

###############################################################################
#                              COMMON BASE
#   Translated from the foundation's Alpine `base` stage to apt, on the glibc
#   Swift base. Same posture; runtime tools only (build tools stay behind).
###############################################################################
FROM swift:${SWIFT_VERSION}-slim@${SWIFT_DIGEST} AS base

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

LABEL org.opencontainers.image.title="swiftdev" \
      org.opencontainers.image.description="Portable, disposable Swift dev environment (langdev suite)" \
      org.opencontainers.image.licenses="Apache-2.0 OR MIT" \
      org.opencontainers.image.vendor="Sebastien Rousseau"

# Runtime deps: multiplexer (tmux — available AND loaded by default via the
# entrypoint) plus the CLI tools the dotfiles expect. `tini` is PID 1 (compose
# sets init:true). `zoxide` is in the Ubuntu 24.04 "noble" universe repo (which
# is enabled in the official Swift/Ubuntu base), so we install it via apt. The
# Swift toolchain (swiftc, swift, sourcekit-lsp, swift-format) is ALREADY in
# this base image on PATH — no separate install. Versions come from the
# digest-locked Ubuntu 24.04 apt repositories of this Swift image.
# hadolint ignore=DL3008,DL3009
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      less \
      mosh \
      ripgrep \
      fd-find \
      fzf \
      bat \
      zoxide \
      tmux \
      ttyd \
      tini \
      tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && update-ca-certificates
# Debian/Ubuntu ship these under alternate names; expose the conventional ones.
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
 && ln -sf "$(command -v batcat)" /usr/local/bin/bat

# Neovim (pinned, sha256-verified tarball) from the env-build stage.
COPY --from=env-build /opt/nvim /opt/nvim
RUN ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

# Non-root user with a real home (Debian/Ubuntu: groupadd/useradd, not adduser).
RUN groupadd -g "${USER_GID}" "${USERNAME}" \
 && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"

# Bring in the fully-populated home from env-build: the applied dotfiles
# (~/.bashrc, ~/.config/tmux, ~/.config/nvim, ~/.config/shell/*, …) plus the
# baked nvim plugin set. One COPY captures everything chezmoi wrote.
COPY --from=env-build --chown=${USER_UID}:${USER_GID} /home/${USERNAME} /home/${USERNAME}

# Entrypoint & IDE tooling (tmux-loading, strict-mode, AI & MCP).
COPY common/entrypoint.sh /usr/local/bin/langdev-entrypoint
COPY common/tmux-ide.sh /usr/local/bin/tmux-ide
COPY common/muxtree.sh /usr/local/bin/muxtree
COPY common/doctor.sh /usr/local/bin/langdev-doctor
COPY common/mcp-server.sh /usr/local/bin/mcp-server
COPY common/ai-pack.sh /usr/local/bin/ai-pack
COPY common/mcp.json /etc/langdev-mcp.json
COPY common/tmux.conf /etc/tmux.conf
RUN chmod 0755 /usr/local/bin/langdev-entrypoint /usr/local/bin/tmux-ide /usr/local/bin/muxtree \
               /usr/local/bin/langdev-doctor /usr/local/bin/mcp-server /usr/local/bin/ai-pack \
 && chmod 0644 /etc/tmux.conf /etc/langdev-mcp.json \
 && mkdir -p /usr/local/lib/langdev

# --- Hardening ---------------------------------------------------------------
# Sticky bit preserved (1777, NOT 777). Remove any setuid/setgid bits so no
# privilege escalation vector survives. No `chattr` theatre (no-op in a
# container). No account-lock theatre — we simply run as an unprivileged user.
RUN chmod 1777 /tmp \
 && find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -exec chmod -s {} + 2>/dev/null || true

USER ${USERNAME}
WORKDIR /work
ENV HOME=/home/${USERNAME} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    EDITOR=nvim \
    XDG_CONFIG_HOME=/home/${USERNAME}/.config \
    XDG_DATA_HOME=/home/${USERNAME}/.local/share \
    XDG_STATE_HOME=/home/${USERNAME}/.local/state \
    XDG_CACHE_HOME=/home/${USERNAME}/.cache

# Cheap, honest liveness probe (no full-FS scans).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD nvim --version >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/langdev-entrypoint"]

###############################################################################
# Stage: final  (Swift runtime)
#   The toolchain is already present in `base` (it IS the official Swift
#   image), so there is no separate toolchain stage to copy from — unlike the
#   Alpine members of the suite. We only drop in the language shell fragment.
#   swiftc / swift / sourcekit-lsp / swift-format are all on PATH at /usr/bin.
###############################################################################
FROM base AS final

# Language shell fragment: Swift PATH + aliases (swift build/test/run, format).
# Installed to /etc/profile.d (root-owned, 0644) so it loads for login shells
# WITHOUT polluting the user's pristine chezmoi dotfiles.
USER root
COPY dotfiles.d/swift.sh /etc/profile.d/swift.sh
RUN chown root:root /etc/profile.d/swift.sh && chmod 0644 /etc/profile.d/swift.sh
USER ${USERNAME}

# sourcekit-lsp, swift, swiftc, swift-format are on PATH via the base image.
ENV PATH=/home/dev/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
