{
  nvf,
  flakePath,
  lib,
  pkgs,
  ...
}: let
  inherit (nvf.lib.nvim) dag;
in {
  # Actual nvim config options, separate to avoid mega indentation
  config.vim = {
    # Enable theming
    theme.enable = true;

    # Treesitter AST Parsing
    treesitter = {
      enable = true;
      textobjects.enable = true;
    };

    # LSP Support
    lsp = {
      enable = true;
      null-ls.enable = true;
      lspsaga.enable = true;
      trouble.enable = true;

      servers.ocaml-lsp.cmd = lib.mkForce ["ocamllsp"];
    };

    # LaTeX Support — vimtex is a VimScript plugin; configure via Lua globals, no setup() call
    extraPlugins = {
      vimtex = {
        package = pkgs.vimPlugins.vimtex;
        setup = ''
          vim.g.vimtex_view_method = 'zathura'
          vim.g.tex_flavour = 'latex'
          vim.g.vimtex_quickfix_mode = 0
          vim.g.tex_conceal = 'abdmg'
        '';
      };
    };

    formatter.conform-nvim.enable = true;

    # Language Settings
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
        format.enable = true; # ocamlformat resolved from active devshell PATH via direnv
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

    telescope.enable = true;

    autocomplete.blink-cmp = {
      enable = true;
      sourcePlugins.ripgrep.enable = true;
      # nvf merges setupOpts.keymap lists with its own defaults by concatenation,
      # so lib.mkForce is required on every entry to replace rather than append.
      setupOpts.keymap = {
        preset = "none";
        "<C-space>" = lib.mkForce ["show" "fallback"];
        # Explicitly clear <CR> — nvf default has ["accept" "fallback"]
        "<CR>" = lib.mkForce ["fallback"];
        "<C-e>" = lib.mkForce ["hide" "fallback"];
        "<C-n>" = lib.mkForce ["select_next" "fallback"];
        "<C-p>" = lib.mkForce ["select_prev" "fallback"];
        # Tab: confirm highlighted item → jump snippet forward → literal tab
        "<Tab>" = lib.mkForce ["select_and_accept" "snippet_forward" "fallback"];
        # S-Tab: jump snippet backward (<C-p> handles completion navigation)
        "<S-Tab>" = lib.mkForce ["snippet_backward" "fallback"];
        # <M-f>/<M-b>: scroll docs — avoids <C-f> clash with Inkscape figure keybind in tex
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
      # UI
      # content.active: mirrors mini.statusline defaults plus snip/spell indicators for tex buffers.
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
      # hues.enable = true;  # Alternative colorscheme; disabled while using Stylix
      icons.enable = true;
      # Text editing
      ai.enable = true;
      operators.enable = true;
      surround.enable = true;
      # Workflow
      bracketed.enable = true;
      files.enable = true;
      pick.enable = true;
    };

    terminal.toggleterm.enable = true;

    utility = {
      diffview-nvim.enable = true;
      direnv.enable = true;
      mkdir.enable = true;
      motion.flash-nvim = {
        enable = true;
        mappings.jump = "<CR>";
        mappings.remote = "<leader>r"; # default "r" overrides operator-pending replace-char
      };
      undotree.enable = true;
    };

    ui.nvim-ufo.enable = true;

    # Lua Configuration files
    additionalRuntimePaths = [
      "${flakePath}/dots/nvim"
    ];
    luaConfigRC.hotswapLua =
      dag.entryAfter ["flakeLua"]
      /*
      lua
      */
      ''
        require("hotswap-lua")
      '';

    luaConfigRC.flakeLua =
      dag.entryAnywhere
      # lua
      ''
        require("flake-lua")
      '';

    # Disable format-on-save globally; use <leader>lf for explicit formatting only.
    # Applies to all languages: nix, lua, rust, ocaml, etc.
    luaConfigRC.formatExplicitOnly =
      dag.entryAfter ["flakeLua"]
      # lua
      ''
        require("conform").setup({ format_on_save = nil })
        vim.keymap.set("n", "<leader>lf", function()
          require("conform").format({ async = true, lsp_fallback = true })
        end, { desc = "Format buffer" })
      '';

    # :Diff3Way <ref> — 3-panel vimdiff: current file | merge-base | <ref>
    # Complements :DiffviewOpen HEAD...<ref> (2-panel, base-anchored).
    # Close with :diffoff | only
    luaConfigRC.diff3Way =
      dag.entryAfter ["flakeLua"]
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
            vim.cmd("$delete _")      -- remove trailing blank line left by 0read
            vim.bo.buftype    = "nofile"
            vim.bo.modifiable = false
            vim.cmd("diffthis")
          end
          open_ro(base)
          open_ro(other)
        end, { nargs = 1, desc = "3-way diff: current | merge-base | <ref>" })
      '';

    # Load all tex snippets once at startup (not per-filetype open) and register
    # the FileType autocmd for LaTeX buffer settings (spell, conceal, inkscape keybinds).
    luaConfigRC.latexSetup =
      dag.entryAfter ["flakeLua"]
      # lua
      ''
        vim.g.latex_snippet_mode = "full"  -- runtime default; cycle with <leader>ls
        require("snippets.init")           -- load all tex snippets once
        require("latex-setup")             -- register FileType autocmd for tex buffers
      '';

    # Mutable fragment overrides (nxc mut) — load all .lua files from the mutable dir
    luaConfigRC.nxcMutable =
      dag.entryAfter ["hotswapLua" "flakeLua" "formatExplicitOnly" "diff3Way" "latexSetup"]
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
