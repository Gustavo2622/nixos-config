-- LaTeX buffer settings: spell check with language cycling, visual concealment,
-- Castel-style Ctrl+L spell correction, snippet mode toggle, and Inkscape figure keybindings.
-- Registered as a FileType autocmd for tex/latex files; loaded once at startup via nvim.nix.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("LatexSetup", { clear = true }),
  pattern = { "tex", "latex" },
  callback = function()

    -- ── Spell check ──────────────────────────────────────────────────────────
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { "en_us" }

    -- Ordered list of spell language presets. Extend here to add more languages.
    -- Last entry enables all at once for multilingual documents.
    local spell_langs = { "en_us", "pt", "fr", "de", "en_us,pt,fr,de" }

    local function spell_cycle(dir)
      local cur_str = table.concat(vim.opt_local.spelllang:get(), ",")
      local idx = 1
      for j, l in ipairs(spell_langs) do
        if l == cur_str then idx = j; break end
      end
      idx = ((idx - 1 + dir) % #spell_langs) + 1
      vim.opt_local.spelllang = spell_langs[idx]
      vim.notify("Spell: " .. spell_langs[idx])
    end

    vim.keymap.set("n", "<leader>sn", function() spell_cycle(1)  end,
      { buffer = true, desc = "Spell: next language" })
    vim.keymap.set("n", "<leader>sp", function() spell_cycle(-1) end,
      { buffer = true, desc = "Spell: prev language" })

    -- Castel-style insert-mode spell corrector: jump to last mistake, fix it,
    -- return to cursor position. Uses <c-g>u to keep undo granularity intact.
    -- <M-l> avoids the nvf default LSP binding on <C-l> (signature help).
    vim.keymap.set("i", "<M-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u",
      { buffer = true, desc = "Fix last spelling mistake" })

    -- ── Visual concealment ───────────────────────────────────────────────────
    -- Hides \[, \], $, and renders \alpha as α, \in as ∈, etc.
    -- Pairs with vim.g.tex_conceal = 'abdmg' set in vimtex extraPlugin setup.
    vim.opt_local.conceallevel = 1

    -- ── Snippet mode toggle ──────────────────────────────────────────────────
    -- Cycles vim.g.latex_snippet_mode: off → basic → full → off
    -- All snippets are already loaded; the mode gates expansion at runtime.
    vim.keymap.set("n", "<leader>lm", function()
      local modes = { "off", "basic", "full" }
      local cur   = vim.g.latex_snippet_mode or "full"
      local idx   = (vim.fn.index(modes, cur) + 1) % #modes
      vim.g.latex_snippet_mode = modes[idx + 1]
      vim.notify("LaTeX snippets: " .. vim.g.latex_snippet_mode)
    end, { buffer = true, desc = "Cycle LaTeX snippet mode (off/basic/full)" })

    -- ── Inkscape figure keybindings ──────────────────────────────────────────
    -- <C-f> in insert: prompt for name, create SVG in ./figures/, insert \incfig{},
    --                  open Inkscape. The inkscape-figures watcher exports on save.
    vim.keymap.set("i", "<C-f>", function()
      local name = vim.fn.input("Figure name: ")
      if name == "" then return end
      local figdir = vim.fn.expand("%:p:h") .. "/figures"
      vim.fn.mkdir(figdir, "p")
      vim.fn.jobstart({ "inkscape-figures", "create", name, figdir })
      vim.api.nvim_put({ "\\incfig{" .. name .. "}" }, "l", true, true)
    end, { buffer = true, desc = "Create Inkscape figure and insert \\incfig{}" })

    -- <C-f> in normal: open rofi picker to choose and edit an existing figure
    vim.keymap.set("n", "<C-f>", function()
      vim.fn.jobstart({ "inkscape-figures", "edit",
        vim.fn.expand("%:p:h") .. "/figures" })
    end, { buffer = true, desc = "Edit existing Inkscape figure" })

  end,
})
