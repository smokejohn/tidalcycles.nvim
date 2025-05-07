local M = {}
local treesitter = require('vim.treesitter')
local utils = require('utils')

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
        preview_sound = '<C-P>',
        send_line = '<C-E>',
        -- silence_line = '<Leader>cml',
        send_node = '<Leader>cs',
        silence_node = '<Leader>cm',
        send_visual = '<C-E>',
        -- silence_visual = '<C-M>',
        hush = '<C-M>',
    },
}

local KEYMAPS = {
    send_line = {
        mode = 'n',
        action = "yy<cmd>lua require('tidalcycles').send_reg()<CR><ESC>",
        description = 'Send line to Tidal',
    },
    silence_line = {
        mode = 'n',
        action = function()
            M.silence_line()
        end,
        description = 'Silence streams in line',
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
    silence_visual = {
        mode = 'v',
        action = function()
            M.silence_visual()
        end,
        description = 'Silence stream in visual selection',
    },
    preview_sound = {
        mode = 'n',
        -- action = "yiw<cmd>lua require('tidalcycles').preview_sound()<CR>",
        action = function()
            M.preview_sound()
        end,
        description = 'Preview sound under cursor with Tidal',
    },
    hush = {
        mode = 'n',
        action = function()
            M.sendline('hush')
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
function M.preview_sound()
    local node = utils.get_node_at_cursor()

    if not node or node:type() ~= 'string' then
        return
    end

    local word = vim.fn.expand('<cWORD>')
    print(word)

    -- M.send('once $ s "' .. text .. '"')
end

--- Silences all streams in the node under the cursor
--- TODO: extend this to also pickup non standard patterns
--- created by the user e.g `p '123'` or `p "test"`
--- TODO: Add a single line version of this function
function M.silence_node()
    local node = utils.get_node_at_cursor()
    if not node then
        print('Got invalid node')
        return
    end

    node = utils.get_ancestor_of_type(node, 'top_splice')
    if not node then
        print('Could not determine top_splice')
        return
    end

    -- a set for all default streams (d1-d16)
    local streamlist = {}
    for i = 1, 16 do
        streamlist['d' .. i] = true
    end

    local used_streams = {}

    -- Gather all variable TSNodes and check if they are d1-d16
    local children = {}
    utils.get_children_of_type(node, 'variable', children)
    for _, child in pairs(children) do
        local node_text = treesitter.get_node_text(child, 0)
        if streamlist[node_text] then
            table.insert(used_streams, node_text)
        end
    end

    if utils.is_empty(used_streams) then
        return
    end

    local silence_cmd = ':{\ndo\n'
    for _, stream in pairs(used_streams) do
        silence_cmd = silence_cmd .. '  ' .. stream .. ' $ silence\n'
    end
    silence_cmd = silence_cmd .. ':}'
    utils.flash_highlight(node, 0, 'Substitute', 250)
    M.sendline(silence_cmd)
end

--- Sends Treesitter Haskell Parser top_splice node to Tidal
function M.send_node()
    local node = utils.get_node_at_cursor()
    if not node then
        print('Got invalid node')
        return
    end

    node = utils.get_ancestor_of_type(node, 'top_splice')
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
    utils.flash_highlight(node, 0, 'Search', 250)
    M.send(text)
end

function M.silence_line() end

function M.silence_visual() end

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
