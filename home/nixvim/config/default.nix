{self, ...}: {
  # Import all your configuration modules here
  imports = [./bufferline.nix];

  colorschemes.catppuccin.enable = true;

  opts = {
    number = true;
    relativenumber = true;

    shiftwidth = 2;
  };

  globals.mapleader = " ";

  plugins = {
    lualine.enable = true;
    oil.enable = true;
    treesitter.enable = true;
    luasnip.enable = true;
    telescope.enable = true;
    lazygit.enable = true;
  };

  # Setup lsps
  plugins.lsp = {
    enable = true;

    servers = {
      lua_ls.enable = true;
      ocamllsp = {
        enable = true;
        package = null; # maybe get the package directly later?
        autostart = true;
      };

      # rust-analyzer.enable = true;
    };
  };

  # Better LSP
  plugins.lspsaga = {
    enable = true;
    beacon.enable = true;

    ui = {
      border = "rounded";
      codeAction = "**"; # Change this later
    };
    hover = {
      openCmd = "!firefox"; # command to open the link
      openLink = "gx"; # key combination for opening the link
    };
    diagnostic = {
      borderFollow = true;
      diagnosticOnlyCurrent = false;
      showCodeAction = true;
    };
    symbolInWinbar.enable = true; # Breadcrumbs

    codeAction = {
      extendGitSigns = false;
      showServerName = true;
      onlyInCursor = true;
      numShortcut = true;
      keys = {
        exec = "<CR>";
        quit = [
          "<Esc>"
          "q"
        ];
      };
    };
    lightbulb = {
      enable = false;
      sign = false;
      virtualText = true;
    };
    implement.enable = false;
    rename = {
      autoSave = false;
      keys = {
        exec = "<CR>";
        quit = [
          "<C-k>"
          "<Esc>"
        ];
        select = "x";
      };
    };
    outline = {
      autoClose = true;
      autoPreview = true;
      closeAfterJump = true;
      layout = "normal";
      winPosition = "right";
      keys = {
        jump = "e";
        quit = "q";
        toggleOrJump = "o";
      };
    };
    scrollPreview = {
      scrollDown = "<C-f>";
      scrollUp = "<C-b>";
    };
  };

  # completions
  plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings = {
      mapping = {
        "<C-d>" = "cmp.mapping.scroll_docs(-4)";
        "<C-f>" = "cmp.mapping.scroll_docs(4)";
        "<C-Space>" = "cmp.mapping.complete()";
        "<C-e>" = "cmp.mapping.close()";
        "<C-n>" = "cmp.mapping(cmp.mapping.select_next_item({behavior = cmp.SelectBehavior.Select}), {'i', 's'})";
        "<C-p>" = "cmp.mapping(cmp.mapping.select_prev_item({behavior = cmp.SelectBehavior.Select}), {'i', 's'})";
        "<Tab>" = "cmp.mapping.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })";
      };

      preselect = "cmp.PreselectMode.None";

      snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";

      sources = [
        {
          name = "nvim_lsp";
          priority = 1000;
        }
        {
          name = "nvim_lsp_signature_help";
          priority = 1000;
        }
        {
          name = "nvim_lsp_document_symbol";
          priority = 1000;
        }
        {
          name = "treesitter";
          priority = 850;
        }
        {
          name = "luasnip";
          priority = 750;
        }
        {
          name = "buffer";
          priority = 500;
        }
        {
          name = "rg";
          priority = 300;
        }
        {
          name = "path";
          priority = 300;
        }
        # Bugged, should be done elsewhere
        #	{
        #	  name = "cmdline";
        #	  priority = 300;
        #	}
        {
          name = "spell";
          priority = 300;
        }
        {
          name = "git";
          priority = 250;
        }
        #	{
        #	  name = "zsh";
        #	  priority = 250;
        #	}
        {
          name = "calc";
          priority = 150;
        }
        {
          name = "emoji";
          priority = 100;
        }
      ];
    };
  };

  plugins.friendly-snippets.enable = true;
  plugins.lspkind = {
    enable = true;
    cmp.enable = true;
    cmp.menu = {
      buffer = "";
      calc = "";
      cmdline = "";
      codeium = "󱜙";
      emoji = "󰞅";
      git = "";
      luasnip = "󰩫";
      neorg = "";
      nvim_lsp = "";
      nvim_lua = "";
      path = "";
      spell = "";
      treesitter = "󰔱";
    };
  };

  highlight = {
    Comment.fg = "#ff00ff";
    Comment.bg = "#000000";
    Comment.underline = true;
    Comment.bold = true;
  };

  keymaps = [
    {
      key = "<CR>";
      action = "cmp.mapping.confirm({select = false })";
    }
    {
      key = "<leader>g";
      action = "<cmd>Telescope live_grep<CR>";
    }
    # LspSaga
    {
      mode = "n";
      key = "gd";
      action = "<cmd>Lspsaga goto_definition<CR>";
      options = {
        desc = "Goto Definition";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "gr";
      action = "<cmd>Lspsaga finder ref<CR>";
      options = {
        desc = "Goto References";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "gy";
      action = "<cmd>Lspsaga goto_type_definition<CR>";
      options = {
        desc = "Goto Type Definition";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<S-k>";
      action = "<cmd>Lspsaga hover_doc<CR>";
      options = {
        desc = "Hover";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>cw";
      action = "<cmd>Lspsaga outline<CR>";
      options = {
        desc = "Outline";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>cr";
      action = "<cmd>Lspsaga rename<CR>";
      options = {
        desc = "Rename";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ca";
      action = "<cmd>Lspsaga code_action<CR>";
      options = {
        desc = "Rename";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>cd";
      action = "<cmd>Lspsaga show_line_diagnostics<CR>";
      options = {
        desc = "Line diagnostics";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "]d";
      action = "<cmd>Lspsaga diagnostic_jump_next<CR>";
      options = {
        desc = "Next Diagnostic";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "]d";
      action = "<cmd>Lspsaga diagnostic_jump_prev<CR>";
      options = {
        desc = "Previous Diagnostic";
        silent = true;
      };
    }
  ];
}
