# ~/.bashrc.d/swift.sh — Swift language fragment (swiftdev)
# SPDX-License-Identifier: MIT
#
# Sourced by the common ~/.bashrc for interactive shells. The Swift
# toolchain (swiftc, swift, sourcekit-lsp, swift-format) is baked into the
# official Swift base image and already lives on PATH at /usr/bin. This
# fragment defensively ensures that prefix is on PATH and adds a few aliases
# ONLY for tools that are actually installed in the image. No host PATH is
# propagated.

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
