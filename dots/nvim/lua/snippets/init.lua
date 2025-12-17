-- Load all tex snippets once at Neovim startup.
-- Snippets carry runtime conditions that read vim.g.latex_snippet_mode, so
-- toggling the mode takes effect immediately without re-running this file.
local ls = require("luasnip")
ls.add_snippets("tex", require("snippets.tex-basic"))
ls.add_snippets("tex", require("snippets.tex-full"))
