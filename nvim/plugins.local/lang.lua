-- swiftdev — Swift language wiring for Neovim (langdev plugins.local spec)
-- SPDX-License-Identifier: Apache-2.0 OR MIT
--
-- Auto-imported by the user's dotfiles Neovim config via its `plugins.local`
-- convention. sourcekit-lsp ships WITH the Swift toolchain in the official
-- Swift image and lives on PATH at /usr/bin/sourcekit-lsp, so we wire it
-- directly through nvim-lspconfig — no Mason, no network on first launch,
-- fully reproducible.
return {
  -- Treesitter grammar for Swift (compiled at build time in env-build).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "swift" })
    end,
  },

  -- SourceKit-LSP via nvim-lspconfig, pointed at the build-time binary.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sourcekit = {
          -- Build-time sourcekit-lsp on PATH (Swift toolchain). The workspace
          -- root (Package.swift / compile_commands.json / .git) and Swift
          -- filetypes come from lspconfig's built-in `sourcekit` defaults.
          cmd = { "sourcekit-lsp" },
        },
      },
    },
  },
}
