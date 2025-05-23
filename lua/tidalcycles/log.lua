local Log = {}

local prefix = '[tidalcycles.nvim]'

function Log.debug(msg)
    vim.notify(prefix .. '(DEBUG): ' .. msg, vim.log.levels.DEBUG)
end

function Log.error(msg)
    vim.notify(prefix .. '(ERROR): ' .. msg, vim.log.levels.ERROR)
end

function Log.info(msg)
    vim.notify(prefix .. '(INFO): ' .. msg, vim.log.levels.INFO)
end

function Log.trace(msg)
    vim.notify(prefix .. '(TRACE): ' .. msg, vim.log.levels.TRACE)
end

function Log.warn(msg)
    vim.notify(prefix .. '(WARN): ' .. msg, vim.log.levels.WARN)
end

return Log
