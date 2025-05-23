local M = {}

--- TODO: Add more checks:
--- * Check if tidalcycles installed
--- * Check if superdirt installed
--- * Check if default superdirt samples found
--- * Check if custom sample folder exists

function M.check_ghci()
    if vim.fn.executable('ghci') == 0 then
        vim.health.error('Couldn\'t execute ghci, it is not available')
    else
        vim.health.ok('ghci installed and available on path')
    end

    if vim.fn.executable('sclang') == 0 then
        vim.health.error('Couldn\'t execute sclang, it is not available')
    else
        vim.health.ok('sclang installed and available on path')
    end

    if vim.fn.executable('hoogle') == 0 then
        vim.health.error('Couldn\'t execute hoogle, it is not available')
    else
        vim.health.ok('hoogle installed and available on path')
    end
end

function M.check()
    vim.health.start('tidalcycles.nvim report')
    M.check_ghci()
end

return M
