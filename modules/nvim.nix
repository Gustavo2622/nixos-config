{
  nvf,
  flakePath,
  lib,
  pkgs,
  ...
}: let
  inherit (nvf.lib.nvim) dag;
  isLinux = pkgs.stdenv.isLinux;
  vimtexViewer =
    if pkgs.stdenv.isDarwin
    then "skim"
    else "zathura";
in {
  config.vim = {
    theme.enable = true;

    # Treesitter AST Parsing
    treesitter = {
      enable = true;
      textobjects.enable = true;
      context.enable = true;
    };

    # LSP Support
    lsp = {
      enable = true;
      null-ls.enable = true;
      lspsaga.enable = true;
      trouble.enable = true;

      servers.ocaml-lsp.cmd = lib.mkForce ["ocamllsp"];
    };

    # LaTeX Support — vimtex is a VimScript plugin; configure via Lua globals
    extraPlugins = {
      vimtex = {
        package = pkgs.vimPlugins.vimtex;
        setup = ''
          vim.g.vimtex_view_method = '${vimtexViewer}'
          vim.g.tex_flavour = 'latex'
          vim.g.vimtex_quickfix_mode = 0
          vim.g.tex_conceal = 'abdmg'
        '';
      };
    };

    formatter.conform-nvim.enable = true;

    # Language Settings — treesitter everywhere, LSP from devShells for rust/ocaml
    languages = {
      nix = {
        enable = true;
        lsp.enable = true;
        treesitter.enable = true;
        format.enable = true;
        extraDiagnostics.enable = true;
      };
      ocaml = {
        enable = true;
        lsp.enable = true;
        treesitter.enable = true;
        format.enable = true;
      };
      lua = {
        enable = true;
        treesitter.enable = true;
        lsp.enable = true;
        format.enable = true;
        extraDiagnostics.enable = true;
      };
      rust = {
        enable = true;
        treesitter.enable = true;
        lsp.enable = true;
        format.enable = true;
        dap.enable = true;
        extensions.crates-nvim.enable = true;
      };
    };

    # telescope removed — mini.pick handles all picker needs

    autocomplete.blink-cmp = {
      enable = true;
      sourcePlugins.ripgrep.enable = true;
      setupOpts.keymap = {
        preset = "none";
        "<C-space>" = lib.mkForce ["show" "fallback"];
        "<CR>" = lib.mkForce ["fallback"];
        "<C-e>" = lib.mkForce ["hide" "fallback"];
        "<C-n>" = lib.mkForce ["select_next" "fallback"];
        "<C-p>" = lib.mkForce ["select_prev" "fallback"];
        "<Tab>" = lib.mkForce ["select_and_accept" "snippet_forward" "fallback"];
        "<S-Tab>" = lib.mkForce ["snippet_backward" "fallback"];
        "<M-f>" = lib.mkForce ["scroll_documentation_down" "fallback"];
        "<M-b>" = lib.mkForce ["scroll_documentation_up" "fallback"];
      };
    };

    git = {
      gitsigns.enable = true;
      vim-fugitive.enable = true;
      neogit.enable = true;
    };

    snippets.luasnip.enable = true;

    mini = {
      statusline = {
        enable = true;
        setupOpts.content.active = lib.generators.mkLuaInline ''
          function()
            local ms = MiniStatusline
            local mode, mode_hl = ms.section_mode({ trunc_width = 120 })
            local git      = ms.section_git({ trunc_width = 75 })
            local diff     = ms.section_diff({ trunc_width = 75 })
            local diag     = ms.section_diagnostics({ trunc_width = 75 })
            local lsp      = ms.section_lsp({ trunc_width = 75 })
            local filename = ms.section_filename({ trunc_width = 140 })
            local fileinfo = ms.section_fileinfo({ trunc_width = 120 })
            local search   = ms.section_searchcount({ trunc_width = 75 })
            local location = ms.section_location({ trunc_width = 75 })
            local extras = {}
            if vim.bo.filetype == "tex" then
              local labels = { off = "snip:off", basic = "snip:basic", full = "snip:full" }
              local snip = labels[vim.g.latex_snippet_mode or "full"]
              local lang = table.concat(vim.opt_local.spelllang:get(), ",")
              if snip then table.insert(extras, snip) end
              if lang ~= "" then table.insert(extras, "spell:" .. lang) end
            end
            return ms.combine_groups({
              { hl = mode_hl,                  strings = { mode } },
              { hl = "MiniStatuslineDevinfo",  strings = { git, diff, diag, lsp } },
              "%<",
              { hl = "MiniStatuslineFilename", strings = { filename } },
              "%=",
              { hl = "MiniStatuslineFileinfo", strings = vim.list_extend({ fileinfo }, extras) },
              { hl = mode_hl,                  strings = { search, location } },
            })
          end
        '';
      };
      tabline.enable = true;
      icons.enable = true;
      ai.enable = true;
      operators.enable = true;
      surround.enable = true;
      bracketed.enable = true;
      files.enable = true;
      pick.enable = true;
      indentscope.enable = true;
      clue.enable = true;
      move.enable = true;
      splitjoin.enable = true;
      visits.enable = true;
    };

    terminal.toggleterm.enable = true;

    utility = {
      diffview-nvim.enable = true;
      direnv.enable = true;
      mkdir.enable = true;
      motion.flash-nvim = {
        enable = true;
        mappings.jump = "<CR>";
        mappings.remote = "<leader>r";
      };
      undotree.enable = true;
    };

    ui.nvim-ufo.enable = true;

    # Runtime lua files (latex snippets, latex-setup autocmd)
    additionalRuntimePaths = [
      "${flakePath}/dots/nvim"
    ];

    # ── Core settings (leader, undo, folds, diagnostics) ──────────────────
    luaConfigRC.coreSettings =
      dag.entryAnywhere
      # lua
      ''
        vim.g.mapleader = " "
        vim.opt.undofile = true
        vim.o.foldlevel = 99
        vim.o.foldcolumn = '0'

        vim.diagnostic.config({
          virtual_text = { spacing = 4, prefix = "●" },
          signs = true,
          underline = true,
          update_in_insert = false,
          severity_sort = true,
          float = { border = "rounded", source = true },
        })
      '';

    # ── Terminal escape ───────────────────────────────────────────────────
    luaConfigRC.terminalEsc =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {silent = true, remap = true})
      '';

    # ── LSP keymaps (via Lspsaga) ────────────────────────────────────────
    luaConfigRC.lspKeymaps =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        vim.keymap.set("n", "]d", ":Lspsaga diagnostic_jump_next<CR>", {silent = true, remap = true, desc = "Next diagnostic"})
        vim.keymap.set("n", "[d", ":Lspsaga diagnostic_jump_prev<CR>", {silent = true, remap = true, desc = "Prev diagnostic"})
        vim.keymap.set("n", "gd", ":Lspsaga goto_definition<CR>", {silent = true, remap = true, desc = "Go to definition"})
        vim.keymap.set("n", "gy", ":Lspsaga goto_type_definition<CR>", {silent = true, remap = true, desc = "Go to type definition"})
        vim.keymap.set("n", "]w", function()
          require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.WARN })
        end, { desc = "Next warning" })
      '';

    # ── Treesitter textobjects (mini.ai) ─────────────────────────────────
    luaConfigRC.treesitterTextobjects =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        local ai = require('mini.ai')
        local spec_treesitter = ai.gen_spec.treesitter
        ai.setup({
          custom_textobjects = {
            f = spec_treesitter({ a = '@function.outer', i = '@function.inner' }),
            c = spec_treesitter({ a = '@class.outer', i = '@class.inner' }),
            o = spec_treesitter({ a = '@conditional.outer', i = '@conditional.inner' }),
          }
        })
      '';

    # ── Buffer / grep keymaps ────────────────────────────────────────────
    luaConfigRC.navigationKeymaps =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        vim.keymap.set("n", "<leader>g", function() MiniPick.builtin.grep_live() end, {desc = "Live grep"})
      '';

    # Disable format-on-save globally; use <leader>lf for explicit formatting only.
    luaConfigRC.formatExplicitOnly =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        require("conform").setup({ format_on_save = nil })
        vim.keymap.set("n", "<leader>lf", function()
          require("conform").format({ async = true, lsp_fallback = true })
        end, { desc = "Format buffer" })
      '';

    # :Diff3Way <ref> — 3-panel vimdiff: current file | merge-base | <ref>
    luaConfigRC.diff3Way =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        vim.api.nvim_create_user_command("Diff3Way", function(opts)
          local other = opts.args
          local base = vim.fn.system("git merge-base HEAD " .. other):gsub("\n", "")
          local file = vim.fn.expand("%")
          vim.cmd("diffthis")
          local function open_ro(ref)
            vim.cmd("vnew")
            vim.cmd("0read !git show " .. ref .. ":" .. file)
            vim.cmd("$delete _")
            vim.bo.buftype    = "nofile"
            vim.bo.modifiable = false
            vim.cmd("diffthis")
          end
          open_ro(base)
          open_ro(other)
        end, { nargs = 1, desc = "3-way diff: current | merge-base | <ref>" })
      '';

    # LaTeX: snippets + autocmd for buffer settings
    luaConfigRC.latexSetup =
      dag.entryAfter ["coreSettings"]
      # lua
      ''
        vim.g.latex_snippet_mode = "full"  -- runtime default; cycle with <leader>lm
        require("snippets.init")
        require("latex-setup")
      '';

    # Mutable fragment overrides (nxc mut) — load all .lua files from the mutable dir
    luaConfigRC.nxcMutable =
      dag.entryAfter ["coreSettings" "lspKeymaps" "treesitterTextobjects" "navigationKeymaps" "formatExplicitOnly" "diff3Way" "latexSetup"]
      # lua
      ''
        local mutable_dir = vim.fn.expand("~/.local/state/mutable/nvim")
        if vim.fn.isdirectory(mutable_dir) == 1 then
          local files = vim.fn.glob(mutable_dir .. "/*.lua", false, true)
          table.sort(files)
          for _, f in ipairs(files) do
            dofile(f)
          end
        end
      '';
  };
}
