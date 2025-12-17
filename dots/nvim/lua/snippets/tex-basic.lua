-- Basic Castel-style LaTeX snippets (~20 essential).
-- All snippets require mode >= "basic" (vim.g.latex_snippet_mode).
-- Math-specific snippets also require the cursor to be inside a math zone.
local ls   = require("luasnip")
local s    = ls.snippet
local sn   = ls.snippet_node
local t    = ls.text_node
local i    = ls.insert_node
local f    = ls.function_node
local d    = ls.dynamic_node
local cond = require("snippets.conditions")

local basic  = cond.mode_at_least("basic")
local in_mz  = cond.in_mathzone
local basic_math = function() return basic() and in_mz() end

-- Mirror the content of node `idx` as text (used for \begin/\end pairs).
local function mirror(idx)
  return f(function(args) return args[1][1] end, { idx })
end

return {
  -- ── Math mode entry ──────────────────────────────────────────────────────
  s({ trig = "mk", wordTrig = false, condition = basic },
    { t("$"), i(1), t("$") }),

  s({ trig = "dm", wordTrig = false, condition = basic },
    { t({ "\\[", "\t" }), i(1), t({ "", "\\]" }) }),

  -- ── Fractions ────────────────────────────────────────────────────────────
  s({ trig = "//", wordTrig = false, condition = basic_math },
    { t("\\frac{"), i(1), t("}{"), i(2), t("}") }),

  -- ── Environments ─────────────────────────────────────────────────────────
  s({ trig = "beg", wordTrig = true, condition = basic },
    { t("\\begin{"), i(1, "env"), t({ "}", "\t" }), i(2), t({ "", "\\end{" }), mirror(1), t("}") }),

  s({ trig = "ali", wordTrig = true, condition = basic },
    { t({ "\\begin{align*}", "\t" }), i(1), t({ "", "\\end{align*}" }) }),

  s({ trig = "eq", wordTrig = true, condition = basic },
    { t({ "\\begin{equation}", "\t" }), i(1), t({ "", "\\end{equation}" }) }),

  s({ trig = "item", wordTrig = true, condition = basic },
    { t({ "\\begin{itemize}", "\t\\item " }), i(1), t({ "", "\\end{itemize}" }) }),

  s({ trig = "enum", wordTrig = true, condition = basic },
    { t({ "\\begin{enumerate}", "\t\\item " }), i(1), t({ "", "\\end{enumerate}" }) }),

  -- ── Superscripts / subscripts ─────────────────────────────────────────────
  s({ trig = "sr", wordTrig = false, condition = basic_math },
    { t("^2") }),

  s({ trig = "cb", wordTrig = false, condition = basic_math },
    { t("^3") }),

  s({ trig = "__", wordTrig = false, condition = basic_math },
    { t("_{"), i(1), t("}") }),

  -- ── Postfix decorators ───────────────────────────────────────────────────
  s({ trig = "hat", wordTrig = false, condition = basic_math },
    { t("\\hat{"), i(1), t("}") }),

  s({ trig = "bar", wordTrig = false, condition = basic_math },
    { t("\\overline{"), i(1), t("}") }),

  s({ trig = "vec", wordTrig = false, condition = basic_math },
    { t("\\vec{"), i(1), t("}") }),

  -- ── Common math symbols ───────────────────────────────────────────────────
  s({ trig = "->", wordTrig = false, condition = basic_math },
    { t("\\to") }),

  s({ trig = "...", wordTrig = false, condition = basic_math },
    { t("\\ldots") }),

  s({ trig = "xx", wordTrig = false, condition = basic_math },
    { t("\\times") }),

  s({ trig = "ooo", wordTrig = false, condition = basic_math },
    { t("\\infty") }),

  -- ── incfig preamble ───────────────────────────────────────────────────────
  -- Inserts the LaTeX packages and \incfig command required for Inkscape figures.
  s({ trig = "incpkg", wordTrig = true, condition = basic }, {
    t({
      "\\usepackage{import}",
      "\\usepackage{xifthen}",
      "\\usepackage{pdfpages}",
      "\\usepackage{transparent}",
      "\\newcommand{\\incfig}[1]{%",
      "    \\def\\svgwidth{\\columnwidth}",
      "    \\import{./figures/}{#1.pdf_tex}",
      "}",
    }),
  }),
}
