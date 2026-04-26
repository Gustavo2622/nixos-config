vim.g.mapleader = " "

vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.keymap.set("n", "gbn", ":bn<CR>", {silent = true, remap = true})
vim.keymap.set("n", "gbp", ":bp<CR>", {silent = true, remap = true})

vim.keymap.set("n", "]d", ":Lspsaga diagnostic_jump_next<CR>", {silent = true, remap = true})
vim.keymap.set("n", "[d", ":Lspsaga diagnostic_jump_prev<CR>", {silent = true, remap = true})
vim.keymap.set("n", "gd", ":Lspsaga goto_definition<CR>", {silent = true, remap = true})
vim.keymap.set("n", "gy", ":Lspsaga goto_type_definition<CR>", {silent = true, remap = true})

vim.keymap.set("n", "<leader>g", ":Telescope live_grep<CR>", {silent = true})

vim.keymap.set("n", "]w", function()
  require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.WARN })
end)

-- Mini.ai treesitter textobjects
local ai = require('mini.ai')
local spec_treesitter = ai.gen_spec.treesitter
ai.setup({
  custom_textobjects = {
    -- Overwrited default function call object
    f = spec_treesitter({ a = '@function.outer', i = '@function.innter' }),
    c = spec_treesitter({ a = '@class.outer', i = '@class.innter' }),
    -- Might conflict with 'mini.indentscope' textobject
    i = spec_treesitter({ a = '@conditional.outer', i = '@conditional.innter' }),
  }
})

-- Decrease starting fold level
vim.o.foldlevel = 99
vim.o.foldcolumn = '0'
