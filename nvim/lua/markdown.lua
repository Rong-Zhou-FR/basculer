-- ~/.config/nvim/lua/markdown.lua
local M = {}

-- Convert a comma list string (without leading indentation) to bullet lines
function M.comma_list_to_md(str)
    if not str or str == "" then
        return {}
    end

    -- Trim the string (no leading/trailing spaces)
    local line = str:match("^%s*(.-)%s*$")

    -- Remove leading bullet markers if present
    line = line:gsub("^[-*+]%s+", "")

    -- Detect the last conjunction (and/et/kaj)
    local conjunctions = { " and ", " et ", " kaj " }
    local last_pos = -1
    local used_conj = nil

    for _, conj in ipairs(conjunctions) do
        local pos = line:find(conj, 1, true)
        if pos and pos > last_pos then
            last_pos = pos
            used_conj = conj
        end
    end

    local items = {}

    if last_pos ~= -1 then
        local left = line:sub(1, last_pos - 1)
        local right = line:sub(last_pos + #used_conj)

        for part in (left .. ","):gmatch("([^,]*),") do
            local trimmed = part:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(items, trimmed)
            end
        end

        local trimmed_right = right:match("^%s*(.-)%s*$")
        if trimmed_right ~= "" then
            table.insert(items, trimmed_right)
        end
    else
        for part in (line .. ","):gmatch("([^,]*),") do
            local trimmed = part:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(items, trimmed)
            end
        end
    end

    -- Build bullet lines (without any indentation)
    local result = {}
    for _, item in ipairs(items) do
        table.insert(result, "- " .. item)
    end
    return result
end

function M.setup()
    vim.api.nvim_create_user_command('CM', function()
        local row = vim.api.nvim_win_get_cursor(0)[1]   -- 1-indexed current line
        local original_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]

        -- Capture leading spaces (indentation)
        local indent = original_line:match("^%s*") or ""
        local extra_indent = "  "   -- 2 spaces for nested level

        -- Trim the original line (remove indentation before processing)
        local trimmed_line = original_line:gsub("^%s+", "")

        local bullet_lines = M.comma_list_to_md(trimmed_line)

        if #bullet_lines == 0 then
            print("No comma list found on this line")
            return
        end

        -- Apply indentation:
        -- First line gets base indent
        -- Subsequent lines get base indent + extra_indent
        local first_line = indent .. bullet_lines[1]
        local rest_lines = {}
        for i = 2, #bullet_lines do
            table.insert(rest_lines, indent .. extra_indent .. bullet_lines[i])
        end

        -- Replace original line with first bullet
        vim.api.nvim_buf_set_lines(0, row-1, row, false, { first_line })

        -- Insert rest bullets below
        if #rest_lines > 0 then
            local insert_pos = row   -- 0-index, after the line we just replaced
            vim.api.nvim_buf_set_lines(0, insert_pos, insert_pos, false, rest_lines)
        end
    end, {})
end

return M
