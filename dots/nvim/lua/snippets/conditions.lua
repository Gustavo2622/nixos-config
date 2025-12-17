-- Shared condition helpers for context-aware LaTeX snippet expansion.
-- mode_at_least(min) gates on vim.g.latex_snippet_mode (off < basic < full).
-- in_mathzone() uses vimtex to detect whether the cursor is inside a math zone.
local M = {}

local rank = { off = 0, basic = 1, full = 2 }

--- Returns a condition function that is true when the current snippet mode is
--- at least `min`. Reads vim.g.latex_snippet_mode at expansion time, so
--- toggling the global takes effect immediately without reloading snippets.
function M.mode_at_least(min)
  return function()
    local cur = vim.g.latex_snippet_mode or "full"
    return (rank[cur] or 2) >= (rank[min] or 0)
  end
end

--- Returns true when the cursor is inside a LaTeX math zone (inline or display).
--- Requires vimtex to be loaded.
function M.in_mathzone()
  return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

return M
