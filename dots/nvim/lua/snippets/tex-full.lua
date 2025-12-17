-- Full Castel-style LaTeX snippet library (~60 additional snippets).
-- All snippets here require mode >= "full" (vim.g.latex_snippet_mode).
-- Most also require the cursor to be inside a math zone (in_mathzone).
local ls   = require("luasnip")
local s    = ls.snippet
local t    = ls.text_node
local i    = ls.insert_node
local f    = ls.function_node
local cond = require("snippets.conditions")

local full      = cond.mode_at_least("full")
local in_mz     = cond.in_mathzone
local full_math = function() return full() and in_mz() end

-- Helper: single-argument math command snippet
local function cmd1(trig, latex)
  return s({ trig = trig, wordTrig = false, condition = full_math },
    { t(latex .. "{"), i(1), t("}") })
end

-- Helper: no-arg math symbol snippet
local function sym(trig, latex)
  return s({ trig = trig, wordTrig = false, condition = full_math }, { t(latex) })
end

return {
  -- ── Greek letters (math zone only) ────────────────────────────────────────
  sym("a",  "\\alpha"),     sym("b",  "\\beta"),
  sym("g",  "\\gamma"),     sym("G",  "\\Gamma"),
  sym("d",  "\\delta"),     sym("D",  "\\Delta"),
  sym("e",  "\\epsilon"),   sym("ve", "\\varepsilon"),
  sym("z",  "\\zeta"),      sym("h",  "\\eta"),
  sym("q",  "\\theta"),     sym("vq", "\\vartheta"),
  sym("i",  "\\iota"),      sym("k",  "\\kappa"),
  sym("l",  "\\lambda"),    sym("L",  "\\Lambda"),
  sym("m",  "\\mu"),        sym("n",  "\\nu"),
  sym("x",  "\\xi"),        sym("X",  "\\Xi"),
  sym("p",  "\\pi"),        sym("P",  "\\Pi"),
  sym("r",  "\\rho"),
  sym("s",  "\\sigma"),     sym("S",  "\\Sigma"),
  sym("t",  "\\tau"),       sym("u",  "\\upsilon"),
  sym("f",  "\\phi"),       sym("F",  "\\Phi"),      sym("vf", "\\varphi"),
  sym("c",  "\\chi"),
  sym("y",  "\\psi"),       sym("Y",  "\\Psi"),
  sym("w",  "\\omega"),     sym("W",  "\\Omega"),

  -- ── Number / letter sets ──────────────────────────────────────────────────
  sym("RR", "\\mathbb{R}"),  sym("ZZ", "\\mathbb{Z}"),
  sym("NN", "\\mathbb{N}"),  sym("QQ", "\\mathbb{Q}"),
  sym("CC", "\\mathbb{C}"),

  -- ── Large operators ───────────────────────────────────────────────────────
  s({ trig = "sum", wordTrig = true, condition = full_math },
    { t("\\sum_{"), i(1, "n=1"), t("}^{"), i(2, "\\infty"), t("}") }),

  s({ trig = "int", wordTrig = true, condition = full_math },
    { t("\\int_{"), i(1, "-\\infty"), t("}^{"), i(2, "\\infty"), t("}") }),

  s({ trig = "lim", wordTrig = true, condition = full_math },
    { t("\\lim_{"), i(1, "n \\to \\infty"), t("}") }),

  sym("dif", "\\mathrm{d}"),

  -- ── Arrows / relations ────────────────────────────────────────────────────
  sym("!>",  "\\mapsto"),
  sym("<=",  "\\le"),
  sym(">=",  "\\ge"),
  sym("!=",  "\\neq"),
  sym("~=",  "\\approx"),
  sym("==",  "\\equiv"),
  sym("**",  "\\cdot"),

  -- ── Delimiters (left/right auto-sizing) ───────────────────────────────────
  s({ trig = "lr(", wordTrig = false, condition = full_math },
    { t("\\left("), i(1), t("\\right)") }),
  s({ trig = "lr[", wordTrig = false, condition = full_math },
    { t("\\left["), i(1), t("\\right]") }),
  s({ trig = "lr{", wordTrig = false, condition = full_math },
    { t("\\left\\{"), i(1), t("\\right\\}") }),
  s({ trig = "lr|", wordTrig = false, condition = full_math },
    { t("\\left|"), i(1), t("\\right|") }),
  s({ trig = "lra", wordTrig = false, condition = full_math },
    { t("\\left\\langle "), i(1), t(" \\right\\rangle") }),

  -- ── More postfix decorators ───────────────────────────────────────────────
  cmd1("dot",   "\\dot"),
  cmd1("ddot",  "\\ddot"),
  cmd1("tilde", "\\tilde"),
  cmd1("und",   "\\underline"),

  -- ── Misc math ─────────────────────────────────────────────────────────────
  s({ trig = "norm", wordTrig = false, condition = full_math },
    { t("\\left\\|"), i(1), t("\\right\\|") }),

  s({ trig = "ceil", wordTrig = false, condition = full_math },
    { t("\\lceil "), i(1), t(" \\rceil") }),

  s({ trig = "floor", wordTrig = false, condition = full_math },
    { t("\\lfloor "), i(1), t(" \\rfloor") }),

  -- ── Auto-subscript: letter followed by single digit → letter_digit ────────
  -- e.g. "a1" → "a_1" in math mode
  s({ trig = "([%a])(%d)", regTrig = true, wordTrig = false, condition = full_math },
    f(function(_, snip) return snip.captures[1] .. "_" .. snip.captures[2] end, {})),

  -- ── Visual-mode fraction: select numerator, press / ───────────────────────
  s({ trig = "/", wordTrig = false, condition = full_math },
    { t("\\frac{"), f(function(_, snip) return snip.env.SELECT_RAW or "" end, {}),
      t("}{"), i(1), t("}") }),
}
