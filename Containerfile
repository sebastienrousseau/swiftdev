# syntax=docker/dockerfile:1.9
# swiftdev Containerfile — OCI, builds with Docker AND Podman.
# SPDX-License-Identifier: MIT
#
# Multi-stage, hardened dev image for Swift. Everything below the
# "COMMON BASE" banner mirrors the langdev suite (kept in sync via
# `make sync-common`), TRANSLATED FROM Alpine/apk TO the glibc/apt base
# that Swift requires.
#
# ARCHITECTURAL DEVIATION (documented in README): the rest of the langdev
# suite builds on Alpine (musl). Swift has NO officially supported
# musl/Alpine toolchain, so swiftdev builds on the OFFICIAL Swift image,
# which is glibc (Ubuntu 24.04 "noble"). We keep the identical security
# posture (non-root, read-only rootfs, cap-drop, no-new-privileges,
# pinned+checksummed inputs) and reuse every distro-agnostic common asset.
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

###############################################################################
# Stage: nvim-build  (COMMON — bakes the editor + plugins into the image)
#   Debian's/Ubuntu's packaged Neovim is often too old for LazyVim, so we
#   install a PINNED, sha256-verified Neovim release tarball from GitHub into
#   /opt/nvim. We then run Neovim headless to install the exact plugin set
#   from lazy-lock.json, so the runtime image needs NO network on first launch.
###############################################################################
FROM swift:${SWIFT_VERSION}-slim@${SWIFT_DIGEST} AS nvim-build
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Pinned Neovim release + per-arch sha256 (verified below). Bump together.
ARG NEOVIM_VERSION=0.12.5
ARG NEOVIM_SHA256_AMD64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
ARG NEOVIM_SHA256_ARM64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725

# Build-time editor deps. `build-essential` + `cmake` build treesitter
# grammars / fzf-native; `ripgrep` + `fd-find` back telescope. These stay in
# this stage and never reach the runtime image.
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
 && rm -rf /var/lib/apt/lists/*

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

ENV PATH=/opt/nvim/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# LazyVim starter pinned to a commit (reproducible); overridable at build.
ARG LAZYVIM_STARTER_REF=c31e5cc9f77b16d20a693c30f28fdf907f1caf95
ENV XDG_CONFIG_HOME=/root/.config \
    XDG_DATA_HOME=/root/.local/share \
    XDG_STATE_HOME=/root/.local/state \
    XDG_CACHE_HOME=/root/.cache
RUN git clone --filter=blob:none https://github.com/LazyVim/starter /root/.config/nvim \
 && git -C /root/.config/nvim checkout "${LAZYVIM_STARTER_REF}" \
 && rm -rf /root/.config/nvim/.git
# Common + language plugin specs (lang.lua wires sourcekit-lsp + treesitter).
COPY common/nvim/plugins/ /root/.config/nvim/lua/plugins/
COPY nvim/plugins/ /root/.config/nvim/lua/plugins/
# Reproducible plugin set: restore from committed lockfile, then sync.
COPY nvim/lazy-lock.json /root/.config/nvim/lazy-lock.json
RUN nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5 || true \
 && nvim --headless "+TSUpdateSync" +qa 2>&1 | tail -n 5 || true

###############################################################################
#                              COMMON BASE
#   Same posture as the rest of the suite, on the glibc Swift base. apk -> apt.
###############################################################################
FROM swift:${SWIFT_VERSION}-slim@${SWIFT_DIGEST} AS base

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

LABEL org.opencontainers.image.title="swiftdev" \
      org.opencontainers.image.description="Portable, disposable Swift dev environment (langdev suite)" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Sebastien Rousseau"

# Minimal, pinned runtime deps. `tini` keeps `docker run` correct even without
# `--init` (compose sets init:true). `ripgrep`/`fd-find` back the editor. The
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
      ripgrep \
      fd-find \
      tini \
      tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && update-ca-certificates
# Debian/Ubuntu ship fd as `fdfind`; expose the conventional `fd` name too.
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# Neovim (pinned, sha256-verified tarball from the nvim-build stage).
COPY --from=nvim-build /opt/nvim /opt/nvim
RUN ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

# Non-root user with a real home (Debian/Ubuntu: groupadd/useradd, not adduser).
RUN groupadd -g "${USER_GID}" "${USERNAME}" \
 && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"

# Portable dotfiles.
COPY --chown=${USER_UID}:${USER_GID} common/dotfiles/bashrc        /home/${USERNAME}/.bashrc
COPY --chown=${USER_UID}:${USER_GID} common/dotfiles/bash_profile  /home/${USERNAME}/.bash_profile
COPY --chown=${USER_UID}:${USER_GID} common/dotfiles/bash_aliases  /home/${USERNAME}/.bash_aliases

# Editor config + baked-in plugins/grammars from the nvim-build stage.
COPY --from=nvim-build --chown=${USER_UID}:${USER_GID} /root/.config/nvim /home/${USERNAME}/.config/nvim
COPY --from=nvim-build --chown=${USER_UID}:${USER_GID} /root/.local/share/nvim /home/${USERNAME}/.local/share/nvim

# Entrypoint.
COPY common/entrypoint.sh /usr/local/bin/langdev-entrypoint
RUN chmod 0755 /usr/local/bin/langdev-entrypoint \
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
COPY --chown=1000:1000 dotfiles.d/swift.sh /home/dev/.bashrc.d/swift.sh

# sourcekit-lsp, swift, swiftc, swift-format are on PATH via the base image.
ENV PATH=/home/dev/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
