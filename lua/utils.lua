local Utils = {}
local treesitter = require('vim.treesitter')
local ts_utils = require('nvim-treesitter.ts_utils')

-- 5.1 compatibility
table.unpack = table.unpack or unpack

--- Highlights the given node with hl_group for the given period
--- @param node TSNode Treesitter node to apply the highlighting to
--- @param bufnr integer Buffer id, or 0 for current buffer
--- @param hl_group string Highlight group, See :h highlight-groups
--- @param timeout integer Time in milliseconds until highlight is cleared
function Utils.flash_highlight_node(node, bufnr, hl_group, timeout)
    ts_utils.highlight_node(node, bufnr, 1, hl_group)

    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, 1, 0, -1)
    end, timeout)
end

--- Highlights the given range with hl_group for the given period
--- @param range integer[] Table containing { start_row, start_col, end_row, end_col }
--- @param bufnr  integer Buffer id, or 0 for current buffer
--- @param hl_group  string Highlight group, see :h highlight-groups
--- @param timeout integer Time in milliseconds until highlight is cleared
function Utils.flash_highlight_range(range, bufnr, hl_group, timeout)
    ts_utils.highlight_range(range, bufnr, 1, hl_group)

    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, 1, 0, -1)
    end, timeout)
end

--- Gets table with range of current line
---@return integer[] { start_row, start_col, end_row, end_col }
function Utils.get_current_line_range()
    local line = vim.fn.line('.')
    return { line - 1, 0, line - 1, vim.fn.col('$') }
end

--- Gets the range of the current visual selection
---@return integer[] table with range { start_row, start_col, end_row, end_col }
function Utils.get_visual_range()
    -- exit out if we are in visual-block mode
    if vim.fn.mode() == '\22' then
        return {}
    end

    local start_pos = vim.fn.getpos('.')
    local end_pos = vim.fn.getpos('v')

    local start_row, start_col = start_pos[2] - 1, start_pos[3] - 1
    local end_row, end_col = end_pos[2] - 1, end_pos[3]

    -- swap range ends depending on cursor position in visual mode (see :h v_o)
    if start_row > end_row or (start_row == end_row and start_col > end_col) then
        start_row, end_row = end_row, start_row
        start_col, end_col = end_col, start_col
    end

    if vim.fn.mode() == 'V' then
        start_col, end_col = 0, -1
    end

    return { start_row, start_col, end_row, end_col }
end

--- Returns true if A contains B, false otherwise
--- @param rangeA integer[] Range A table { start_row, start_col, end_row, end_col }
--- @param rangeB integer[] Range B table { start_row, start_col, end_row, end_col }
function Utils.range_contains(rangeA, rangeB)
    local startA_row, startA_col, endA_row, endA_col = table.unpack(rangeA)
    local startB_row, startB_col, endB_row, endB_col = table.unpack(rangeB)
    if
        (startA_row < startB_row or (startA_row == startB_row and startA_col <= startB_col))
        and (endA_row > endB_row or (endA_row == endB_row and endA_col >= endB_col))
    then
        return true
    else
        return false
    end
end

--- Gets all TSNodes in the given range
---@param range integer[] Range table { start_row, start_col, end_row, end_col }
---@return TSNode[] table of TSNodes
function Utils.get_nodes_in_range(range)
    local parser = treesitter.get_parser()
    if not parser then
        return {}
    end

    local root = parser:parse()[1]:root()

    local nodes = {}
    local function collect_nodes(node)
        if Utils.range_contains(range, { node:range() }) then
            table.insert(nodes, node)
        end

        for child in node:iter_children() do
            collect_nodes(child)
        end
    end

    collect_nodes(root)
    return nodes
end

function Utils.get_node_at_cursor()
    -- Holds the (0,0) indexed cursor position
    -- We check the cursor position here and push the cursor to column 1 if it
    -- rests in column 0 since the haskell parser for treesitter returns the
    -- first child of the whole tree (declarations node) in this case
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    -- convert to (0,0) indexed position instead of (1,0)
    cursor_pos[1] = cursor_pos[1] - 1
    if cursor_pos[2] == 0 then
        cursor_pos[2] = 1
    end

    -- The node at the current cursor position
    local node = treesitter.get_node({ bufnr = 0, pos = cursor_pos })
    if not node then
        return nil
    end

    return node
end

--- Gets the nearest ancestor node of specified type from treesitter
--- @param node TSNode
--- @param type string
--- @return TSNode?
function Utils.get_ancestor_of_type(node, type)
    local root = node:tree():root()
    local parent = node:parent()

    -- Walk up the nodetree until we find a parent of type
    while node ~= nil and node ~= root do
        if node:type() == type then
            break
        end
        node = parent
        if node then
            parent = node:parent()
        end
    end

    if not node or node == root then
        return nil
    end

    return node
end

--- Gets all children with type
---@param node TSNode
---@param type string
---@param children TSNode[]
---@param depth integer
function Utils.get_children_of_type(node, type, children, depth)
    if not node then
        return nil
    end
    depth = depth or 0

    for child in node:iter_children() do
        if child:type() == type then
            table.insert(children, child)
        end
        Utils.get_children_of_type(child, type, children, depth + 1)
    end
end

function Utils.is_empty(table)
    return next(table) == nil
end

return Utils
