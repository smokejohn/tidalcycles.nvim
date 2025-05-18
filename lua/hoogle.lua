local Hoogle = {}

-- 5.1 compatibility
table.unpack = table.unpack or unpack

function Hoogle.query_database(query)
    -- TODO: make async
    local process_result = vim.system({ 'hoogle', '-i', query }, { text = true }):wait()

    if not process_result.stdout then
        return {}
    end
    local query_result = vim.split(process_result.stdout, '\n', {})

    return query_result
end

function Hoogle.generate_database()
    local process_result = vim.system({ 'hoogle', 'generate', 'tidal' }):wait()
end

return Hoogle
