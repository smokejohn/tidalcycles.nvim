local M = {}
local ts_utils = require('vim.treesitter')

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
        -- send_node = '<Leader>s',
        send_visual = '<C-E>',
        preview_sound = '<C-P>',
        hush = '<C-M>',
    },
}

local KEYMAPS = {
    send_line = {
        mode = 'n',
        action = "yy<cmd>lua require('tidalcycles').send_reg()<CR><ESC>",
        description = 'send line to Tidal',
    },
    -- send_node = {
    --     mode = 'n',
    --     action = function()
    --         M.send_node()
    --     end,
    --     description = 'send treesitter node to Tidal',
    -- },
    send_visual = {
        mode = 'v',
        action = "y<cmd>lua require('tidalcycles').send_reg()<CR>",
        description = 'send selection to Tidal',
    },
    preview_sound = {
        mode = 'n',
        action = "yiw<cmd>lua require('tidalcycles').preview_sound()<CR>",
        description = 'preview sound under cursor with Tidal',
    },
    hush = {
        mode = 'n',
        action = function()
            M.send('hush')
        end,
        description = "send 'hush' to Tidal",
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
    vim.api.nvim_chan_send(state.tidal_process, text .. '\n')
end

function M.send_reg(register)
    if not register then
        register = ''
    end
    local text = table.concat(vim.fn.getreg(register, 1, true), '\n')
    M.send(':{\n' .. text .. '\n:}')
end

function M.preview_sound(sound)
    if not sound then
        sound = ''
    end
    local text = table.concat(vim.fn.getreg(sound, 1, true))
    M.send('once $ s "' .. text .. '"')
end

-- TODO: Fix this function
-- Currently fails because of deprecated calls (just a guess, need to test more)
function M.send_node()
    local node = ts_utils.get_node_at_cursor(0)
    local root
    if node then
        root = ts_utils.get_root_for_node(node)
    end
    if not root then
        return
    end
    local parent
    if node then
        parent = node:parent()
    end
    while node ~= nil and node ~= root do
        local t = node:type()
        if t == 'top_splice' then
            break
        end
        node = parent
        if node then
            parent = node:parent()
        end
    end
    if not node then
        return
    end
    local start_row, start_col, end_row, end_col = ts_utils.get_node_range(node)
    local text = table.concat(vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {}), '\n')
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
