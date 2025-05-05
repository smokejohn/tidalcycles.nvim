local M = {}
local treesitter = require('vim.treesitter')
local ts_utils = require('nvim-treesitter.ts_utils')

local DEFAULTS = {
    boot = {
        tidal = {
            file = vim.api.nvim_get_runtime_file('BootTidal.hs', false)[1],
            args = {},
        },
        sclang = {
            file = vim.api.nvim_get_runtime_file('BootSuperDirt.scd', false)[1],
            enabled = false,
        },
        split = 'v',
    },
    keymaps = {
        send_line = '<C-E>',
        send_node = '<Leader>cs',
        silence_node = '<Leader>cm',
        send_visual = '<C-E>',
        preview_sound = '<C-P>',
        hush = '<C-M>',
    },
}

local KEYMAPS = {
    send_line = {
        mode = 'n',
        action = "yy<cmd>lua require('tidalcycles').send_reg()<CR><ESC>",
        description = 'Send line to Tidal',
    },
    send_node = {
        mode = 'n',
        action = function()
            M.send_node()
        end,
        description = 'Send treesitter node to Tidal',
    },
    silence_node = {
        mode = 'n',
        action = function()
            M.silence_node()
        end,
        description = 'Silence all streams contained in the treesitter node',
    },
    send_visual = {
        mode = 'v',
        action = "y<cmd>lua require('tidalcycles').send_reg()<CR>",
        description = 'Send selection to Tidal',
    },
    preview_sound = {
        mode = 'n',
        action = "yiw<cmd>lua require('tidalcycles').preview_sound()<CR>",
        description = 'Preview sound under cursor with Tidal',
    },
    hush = {
        mode = 'n',
        action = function()
            M.send('hush')
        end,
        description = "Send 'hush' to Tidal",
    },
}

local state = {
    launched = false,
    tidal = nil,
    sclang = nil,
    tidal_process = nil,
    sclang_process = nil,
}

local function boot_tidal(args)
    if state.tidal then
        local ok = pcall(vim.api.nvim_set_current_buf, state.tidal)
        if not ok then
            state.tidal = nil
            boot_tidal(args)
            return
        end
    else
        state.tidal = vim.api.nvim_create_buf(false, false)
        boot_tidal(args)
        return
    end
    state.tidal_process = vim.fn.termopen('ghci -ghci-script=' .. args.file, {
        on_exit = function()
            if #vim.fn.win_findbuf(state.tidal) > 0 then
                vim.api.nvim_win_close(vim.fn.win_findbuf(state.tidal)[1], true)
            end
            vim.api.nvim_buf_delete(state.tidal, { force = true })
            state.tidal = nil
            state.tidal_process = nil
        end,
    })
    vim.cmd('normal! G')
end

local function boot_sclang(args)
    if not args.enabled then
        return
    end
    if state.sclang then
        local ok = pcall(vim.api.nvim_set_current_buf, state.sclang)
        if not ok then
            state.sclang = nil
            boot_sclang(args)
        end
    else
        state.sclang = vim.api.nvim_create_buf(false, false)
        boot_sclang(args)
        return
    end
    state.sclang_process = vim.fn.termopen('sclang ' .. args.file, {
        on_exit = function()
            if #vim.fn.win_findbuf(state.sclang) > 0 then
                vim.api.nvim_win_close(vim.fn.win_findbuf(state.sclang)[1], true)
            end
            vim.api.nvim_buf_delete(state.sclang, { force = true })
            state.sclang = nil
            state.sclang_process = nil
        end,
    })
    vim.cmd('normal! G')
end

local function launch_tidal(args)
    local current_win = vim.api.nvim_get_current_win()
    if state.launched then
        return
    end
    vim.cmd(args.split == 'v' and 'vsplit' or 'split')
    boot_tidal(args.tidal)
    if args.sclang.enabled then
        vim.cmd(args.split == 'v' and 'split' or 'vsplit')
        boot_sclang(args.sclang)
    end
    vim.api.nvim_set_current_win(current_win)
    state.launched = true
end

local function exit_tidal()
    if not state.launched then
        return
    end
    if state.tidal_process then
        vim.fn.jobstop(state.tidal_process)
    end
    if state.sclang_process then
        vim.fn.jobstop(state.sclang_process)
    end
    state.launched = false
end

--- Highlights the given node with hl_group for the given period
--- @param node TSNode Treesitter node to apply the highlighting to
--- @param bufnr integer Buffer id, or 0 for current buffer
--- @param hl_group string Highlight group, See :h highlight-groups
--- @param timeout integer Time in milliseconds until highlight is cleared
local function flash_highlight(node, bufnr, hl_group, timeout)
    ts_utils.highlight_node(node, bufnr, 1, hl_group)

    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(bufnr, 1, 0, -1)
    end, timeout)
end

local function key_map(key, mapping)
    vim.keymap.set(KEYMAPS[key].mode, mapping, KEYMAPS[key].action, {
        buffer = true,
        desc = KEYMAPS[key].description,
    })
end

function M.send(text)
    if not state.tidal_process then
        return
    end
    vim.api.nvim_chan_send(state.tidal_process, ':{\n' .. text .. '\n:}' .. '\n')
end

function M.sendline(text)
    if not state.tidal_process then
        return
    end
    vim.api.nvim_chan_send(state.tidal_process, text .. '\n')
end

function M.send_reg(register)
    if not register then
        register = ''
    end
    local text = table.concat(vim.fn.getreg(register, 1, true), '\n')
    M.send(text)
end

--- Plays the sample under the cursor once
--- TODO: Improve this so it plays only available samples
--- TODO: Improve this so it plays the selected sample if specified
--- (respects bd:4 and plays the fourth sample of bd folder instead of just the first one)
--- TODO: Improve this so it plays all samples in a folder in ascending order if it
--- is activated multiple times on a sample name without a sample specification (i.e bd vs. bd:4)
--- @param register string
function M.preview_sound(register)
    if not register then
        register = ''
    end
    local text = table.concat(vim.fn.getreg(register, 1, true))
    M.send('once $ s "' .. text .. '"')
end

local function get_node_at_cursor()
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
local function get_ancestor_of_type(node, type)
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
local function get_children_of_type(node, type, children, depth)
    if not node then
        return nil
    end
    depth = depth or 0

    for child in node:iter_children() do
        if child:type() == type then
            table.insert(children, child)
        end
        get_children_of_type(child, type, children, depth + 1)
    end
end

--- Silences all streams in the node under the cursor
function M.silence_node()
    local node = get_node_at_cursor()
    if not node then
        print('Got invalid node')
        return
    end

    node = get_ancestor_of_type(node, 'top_splice')
    if not node then
        print('Could not determine top_splice')
        return
    end

    local children = {}
    get_children_of_type(node, 'variable', children)
    for _, child in pairs(children) do
        print(node:sexpr())
    end
end

--- Sends Treesitter Haskell Parser top_splice node to Tidal
function M.send_node()
    local node = get_node_at_cursor()
    if not node then
        print('Got invalid node')
        return
    end

    node = get_ancestor_of_type(node, 'top_splice')
    if not node then
        print('Could not determine top_splice')
        return
    end

    -- fix end_row for nvim_buf_get_text call when node range goes to EOF
    local bufferlength = vim.api.nvim_buf_line_count(0) - 1
    local start_row, start_col, end_row, end_col = treesitter.get_node_range(node)
    if end_row > bufferlength then
        end_row = bufferlength
    end
    local bufferlines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})

    local text = table.concat(bufferlines, '\n')
    flash_highlight(node, 0, 'Search', 250)
    M.send(text)
end

function M.setup(args)
    args = vim.tbl_deep_extend('force', DEFAULTS, args)

    vim.api.nvim_create_user_command('TidalStart', function()
        launch_tidal(args.boot)
    end, { desc = 'launches Tidal instance, including sclang if so configured' })

    vim.api.nvim_create_user_command('TidalStop', exit_tidal, { desc = 'quits Tidal instance' })

    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
        pattern = { '*.tidal' },
        callback = function()
            vim.cmd('set ft=haskell')
            for key, value in pairs(args.keymaps) do
                key_map(key, value)
            end
        end,
    })
end

return M
