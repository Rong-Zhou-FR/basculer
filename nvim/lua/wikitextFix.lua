-- ~/.config/nvim/lua/wikitextFix.lua
--
-- Pre-publish cleanup for wikitext rendered by MediaWiki + SimpleMathJax
-- (MathJax 3, client-side). The pass:
--
--   1. converts inline <syntaxhighlight ... inline> ... </syntaxhighlight> to <code> ... </code>
--   2. normalises math delimiters: \( ... \) -> $ ... $ and \[ ... \] -> $$ ... $$
--   3. inside $$ ... $$: collapses blank lines and escapes < > as \lt \gt
--   4. inside remaining $ ... $: escapes < > as \lt \gt
--
-- (3) exists because MediaWiki ends the paragraph at a blank line (so the
-- delimiters land in different DOM nodes and MathJax never sees a complete
-- $$ ... $$ pair) and because its HTML parser turns <q ...> into a tag.
--
-- Contents of <code>, <pre>, <nowiki>, <source> and <syntaxhighlight> are
-- masked first, so the math transforms never rewrite code samples.
--
-- Run :WTF on the buffer before publishing.
local M = {}

local PROTECTED_TAGS = {
  code = true,
  pre = true,
  nowiki = true,
  source = true,
  syntaxhighlight = true,
}

local sentinelCounter = 0

local function newSentinel()
  sentinelCounter = sentinelCounter + 1
  return "\1wikitextFix#" .. sentinelCounter .. "\1"
end

-- Replace each protected region with an inert placeholder; the original text is
-- kept in `masks` and restored after the math transforms.
local function maskProtectedRegions(text, masks)
  local lower = text:lower()
  local out = {}
  local pos = 1

  while true do
    local lt = lower:find("<", pos, true)
    if lt == nil then
      break
    end

    local name = lower:sub(lt + 1):match("^(%a[%w%-]*)")
    if name ~= nil and PROTECTED_TAGS[name] then
      local openEnd = lower:find(">", lt + #name + 1, true)
      if openEnd == nil then
        break
      end

      local closeTag = "</" .. name .. ">"
      local closeStart = lower:find(closeTag, openEnd + 1, true)
      if closeStart == nil then
        -- Unclosed container: leave the opening tag alone and keep scanning.
        out[#out + 1] = text:sub(pos, openEnd)
        pos = openEnd + 1
      else
        local regionEnd = closeStart + #closeTag - 1
        local sentinel = newSentinel()
        masks[#masks + 1] = { sentinel = sentinel, original = text:sub(lt, regionEnd) }
        out[#out + 1] = text:sub(pos, lt - 1)
        out[#out + 1] = sentinel
        pos = regionEnd + 1
      end
    else
      out[#out + 1] = text:sub(pos, lt)
      pos = lt + 1
    end
  end

  out[#out + 1] = text:sub(pos)
  return table.concat(out)
end

-- Restore in reverse insertion order: a display-math placeholder can contain a
-- code placeholder, so it must be expanded first.
local function restoreMasks(text, masks)
  for i = #masks, 1, -1 do
    local mask = masks[i]
    local start = text:find(mask.sentinel, 1, true)
    if start == nil then
      error("wikitextFix: internal error: lost placeholder #" .. i)
    end
    text = text:sub(1, start - 1) .. mask.original .. text:sub(start + #mask.sentinel)
  end
  return text
end

local function escapeAngles(body)
  body = body:gsub("<", "\\lt ")
  body = body:gsub(">", "\\gt ")
  return body
end

-- Normalise \( ... \) and \[ ... \] in one left-to-right pass, mirroring the
-- Vim substitution: whichever opener comes first wins, the inline form stops at
-- a newline, and an opener without a closer is left untouched.
local function normaliseDelimiters(text)
  local out = {}
  local pos = 1

  while pos <= #text do
    local inline = text:find("\\(", pos, true)
    local display = text:find("\\[", pos, true)

    if inline == nil and display == nil then
      out[#out + 1] = text:sub(pos)
      break
    end

    local opener, closer, wrap, inlineForm
    if display == nil or (inline ~= nil and inline < display) then
      opener, closer, wrap, inlineForm = inline, "\\)", "$", true
    else
      opener, closer, wrap, inlineForm = display, "\\]", "$$", false
    end

    out[#out + 1] = text:sub(pos, opener - 1)

    local close
    if inlineForm then
      local lineEnd = text:find("\n", opener, true)
      local candidate = text:find(closer, opener + 2, true)
      if candidate ~= nil and (lineEnd == nil or candidate < lineEnd) then
        close = candidate
      end
    else
      close = text:find(closer, opener + 2, true)
    end

    if close == nil then
      -- No closer: leave the opener as literal text and keep scanning after it.
      out[#out + 1] = text:sub(opener, opener + 1)
      pos = opener + 2
    else
      out[#out + 1] = wrap .. text:sub(opener + 2, close - 1) .. wrap
      pos = close + 2
    end
  end

  return table.concat(out)
end

function M.wikitextFix()
  local buf = vim.api.nvim_get_current_buf()
  local original = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local text = original
  sentinelCounter = 0

  -- An odd number of '$' means at least one span is unterminated.
  local dollars = select(2, text:gsub("%$", ""))
  if dollars % 2 ~= 0 then
    vim.notify(
      ("wikitextFix: odd number of '$' (%d) — a math span is unbalanced; the trailing block was skipped"):format(dollars),
      vim.log.levels.WARN
    )
  end

  -- Inline syntaxhighlight -> code. Done before masking so the new <code>
  -- regions are protected as well.
  text = text:gsub("<syntaxhighlight[^>]*inline>([^\n]-)</syntaxhighlight>", "<code>%1</code>")

  local masks = {}
  text = maskProtectedRegions(text, masks)

  text = normaliseDelimiters(text)

  -- Display-math cleanup. Each cleaned block is replaced by a placeholder so
  -- the inline pass below cannot pair a '$' across two display blocks.
  local blocks = 0
  text = text:gsub("%$%$(.-)%$%$", function(body)
    blocks = blocks + 1

    while body:find("\n[ \t\r]*\n") do
      body = body:gsub("\n[ \t\r]*\n", "\n")
    end

    local sentinel = newSentinel()
    masks[#masks + 1] = { sentinel = sentinel, original = "$$" .. escapeAngles(body) .. "$$" }
    return sentinel
  end)

  -- Inline math.
  text = text:gsub("%$([^%$\n]+)%$", function(body)
    return "$" .. escapeAngles(body) .. "$"
  end)

  local fixed = restoreMasks(text, masks)

  if fixed == original then
    vim.notify("wikitextFix: already clean")
    return blocks
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(fixed, "\n", { plain = true }))
  if blocks == 0 then
    vim.notify("wikitextFix: updated buffer (delimiters / inline code normalised)")
  else
    vim.notify(("wikitextFix: updated buffer (%d display-math block(s) cleaned)"):format(blocks))
  end
  return blocks
end

function M.setup()
  vim.api.nvim_create_user_command("WTF", function()
    M.wikitextFix()
  end, { desc = "Clean wikitext for MediaWiki (math delimiters, inline code, $ and $$ spans)" })
end

return M
