# /etc/profile.d/swift.sh — Swift language fragment (swiftdev)
# SPDX-License-Identifier: MIT
#
# Installed to /etc/profile.d (root-owned, 0644) and sourced by /etc/profile
# for login shells — kept OUT of the user's chezmoi dotfiles so those stay
# pristine and langdev-agnostic. The Swift toolchain (swiftc, swift,
# sourcekit-lsp, swift-format) is baked into the official Swift base image and
# already lives on PATH at /usr/bin. This fragment defensively ensures that
# prefix is on PATH and adds a few aliases ONLY for tools that are actually
# installed in the image. No host PATH is propagated.

# Toolchain prefix (already on PATH in the base image; kept explicit so the
# environment is self-documenting and robust to PATH edits).
case ":${PATH}:" in
  *":/usr/bin:"*) ;;
  *) export PATH="/usr/bin:${PATH}" ;;
esac

# --- Aliases (only for tools present in the image) ---------------------------
alias sb='swift build'
alias sr='swift run'
alias st='swift test'
# swift-format ships with the toolchain; invoke via the `swift format` subcommand.
alias sfmt='swift format'
alias sfmti='swift format --in-place'
