local Hoogle = {}
local utils = require('tidalcycles.utils')
local log = require('tidalcycles.log')

-- 5.1 compatibility
table.unpack = table.unpack or unpack

local doc_buffer = nil
local doc_window = nil

function Hoogle.init()
    -- test if hoogle is installed on system / available on path
    if vim.fn.executable('hoogle') == 0 then
        log.info('hoogle not found on system, not setting up documentation provider')
        return
    end

    -- check if database has been generated
    local cmd_result = vim.system({ 'hoogle' }, { text = true }):wait()
    if cmd_result.stderr ~= '' and string.match(cmd_result.stderr, 'hoogle generate') then
        log.info('hoogle database not generated, not setting up documentation provider! ' ..
                 'please run "hoogle generate tidal" on the commandline')
        return
    end

    vim.api.nvim_create_autocmd('CursorMoved', {
        callback = function()
            if doc_window then
                vim.api.nvim_win_close(doc_window, false)
                doc_window = nil
            end
        end,
    })
end

function Hoogle.query_database(query)
    -- TODO: make async
    local process_result = vim.system({ 'hoogle', '-i', query }, { text = true }):wait()

    if not process_result.stdout then
        return {}
    end
    local query_result = vim.split(process_result.stdout, '\n', {})

    -- TODO: filter result, catch cases with no practical result and display message
    return query_result
end

function Hoogle.generate_database()
    local process_result = vim.system({ 'hoogle', 'generate', 'tidal' }):wait()
end

function Hoogle.show_docs()
    local word = vim.fn.expand('<cWORD>')
    local query_result = Hoogle.query_database(word)
    local window_width = utils.longest_line_in_table(query_result)

    doc_buffer = vim.api.nvim_create_buf(false, true)
    -- TODO: set buffer to markdown and use highlighting to improve readability
    vim.api.nvim_buf_set_lines(doc_buffer, 0, -1, true, query_result)
    local opts = {
        border = 'rounded',
        relative = 'cursor',
        col = 0,
        row = 1,
        width = window_width,
        height = #query_result,
        style = 'minimal',
    }
    if doc_window == nil then
        doc_window = vim.api.nvim_open_win(doc_buffer, false, opts)
        -- optional: change highlight, otherwise Pmenu is used
        -- vim.api.nvim_set_option_value('winhl', 'Normal:MyHighlight', {win})
    end
end

return Hoogle
