--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}
local utils = require('utils')

--- Browses Sound.Tidal.Context for a list of available functions
--- @return string[]?
--- TODO: Make this function start the subprocess async
function source.browse_tidal()
    local process_result = vim.system({ 'ghci', '-ignore-dot-ghci' }, { text = true, stdin = { 'import Sound.Tidal.Context', ':browse Sound.Tidal.Context' } })
        :wait()
    if process_result.stderr ~= '' then
        print('Could not obtain available tidal functions')
        return nil
    end

    if process_result.stdout == '' then
        return nil
    end

    local raw_lines = vim.split(process_result.stdout, '\n')
    -- discard first and last line (they unneeded contain ghci repl output)
    raw_lines = utils.slice_table(raw_lines, 2, -2)

    -- truncate first line to get rid of ghci> repl characters
    -- we disable .ghci-config file to ensure prompt looks like ghci>
    raw_lines[1] = raw_lines[1]:gsub('ghci> ', '')

    -- Putting each entry on its own line
    local lines = {}
    for _, line in pairs(raw_lines) do
        -- matching lines that start with one or more whitespaces followed by any other character
        -- these lines are indented continuation lines that we need to join to the previous line
        local _, match_end = string.find(line, '^%s+%S')
        if match_end then
            lines[#lines] = lines[#lines] .. string.sub(line, match_end - 1)
        else
            table.insert(lines, line)
        end
    end

    -- ignore lines that start with data, [new]type, class or an underscore
    local functions = {}
    for _, line in pairs(lines) do
        if not (line:match('^type') or line:match('^newtype') or line:match('^data') or line:match('^class') or line:match('^_')) then
            table.insert(functions, line)
        end
    end

    return functions
end

local functions = {}

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
function source.new(opts)
  -- vim.validate('your_source.opts.some_option', opts.some_option, { 'string' })
  -- vim.validate('your_source.opts.optional_option', opts.optional_option, { 'string' }, true)

  print("Custom blink source being created")
  functions = source.browse_tidal()

  local self = setmetatable({}, { __index = source })
  self.opts = opts
  return self
end

-- (Optional) Enable the source in specific contexts only
-- function source:enabled() return vim.bo.filetype == 'haskell' end

-- (Optional) Non-alphanumeric characters that trigger the source
-- function source:get_trigger_characters() return { '.' } end

function source:get_completions(ctx, callback)
  -- ctx (context) contains the current keyword, cursor position, bufnr, etc.

  -- You should never filter items based on the keyword, since blink.cmp will
  -- do this for you

  print(#functions)
  local items = {}
  for _, func in pairs(functions) do
  --- @type lsp.CompletionItem[]
    local item = {
      label = func,
      kind = require('blink.cmp.types').CompletionItemKind.Text,
      -- May be Snippet or PlainText
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    }
    table.insert(items, item)
  end

  --[[
  for i = 1, 10 do
    --- @type lsp.CompletionItem
    local item = {
      -- Label of the item in the UI
      label = 'foo',
      -- (Optional) Item kind, where `Function` and `Method` will receive
      -- auto brackets automatically
      kind = require('blink.cmp.types').CompletionItemKind.Text,

      -- (Optional) Text to fuzzy match against
      filterText = 'bar',
      -- (Optional) Text to use for sorting. You may use a layout like
      -- 'aaaa', 'aaab', 'aaac', ... to control the order of the items
      sortText = 'baz',

      -- Text to be inserted when accepting the item using ONE of:
      --
      -- (Recommended) Control the exact range of text that will be replaced
      textEdit = {
        newText = 'item ' .. i,
        range = {
          -- 0-indexed line and character
          start = { line = 0, character = 0 },
          ['end'] = { line = 0, character = 0 },
        },
      },
      -- Or get blink.cmp to guess the range to replace for you. Use this only
      -- when inserting *exclusively* alphanumeric characters. Any symbols will
      -- trigger complicated guessing logic in blink.cmp that may not give the
      -- result you're expecting
      -- Note that blink.cmp will use `label` when omitting both `insertText` and `textEdit`
      insertText = 'foo',
      -- May be Snippet or PlainText
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,

      -- There are some other fields you may want to explore which are blink.cmp
      -- specific, such as `score_offset` (blink.cmp.CompletionItem)
    }
    table.insert(items, item)
  end
  ]]

  -- The callback _MUST_ be called at least once. The first time it's called,
  -- blink.cmp will show the results in the completion menu. Subsequent calls
  -- will append the results to the menu to support streaming results.
  callback({
    items = items,
    -- Whether blink.cmp should request items when deleting characters
    -- from the keyword (i.e. "foo|" -> "fo|")
    -- Note that any non-alphanumeric characters will always request
    -- new items (excluding `-` and `_`)
    is_incomplete_backward = false,
    -- Whether blink.cmp should request items when adding characters
    -- to the keyword (i.e. "fo|" -> "foo|")
    -- Note that any non-alphanumeric characters will always request
    -- new items (excluding `-` and `_`)
    is_incomplete_forward = false,
  })

  -- (Optional) Return a function which cancels the request
  -- If you have long running requests, it's essential you support cancellation
  return function() end
end

-- (Optional) Before accepting the item or showing documentation, blink.cmp will call this function
-- so you may avoid calculating expensive fields (i.e. documentation) for only when they're actually needed
function source:resolve(item, callback)
  item = vim.deepcopy(item)

  -- Shown in the documentation window (<C-space> when menu open by default)
  item.documentation = {
    kind = 'markdown',
    value = '# Foo\n\nBar',
  }

  -- Additional edits to make to the document, such as for auto-imports
  --[[
  item.additionalTextEdits = {
    {
      newText = 'foo',
      range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 0, character = 0 },
      },
    },
  }
  ]]

  callback(item)
end

-- Called immediately after applying the item's textEdit/insertText
function source:execute(ctx, item, callback, default_implementation)
  -- By default, your source must handle the execution of the item itself,
  -- but you may use the default implementation at any time
  default_implementation()

  -- The callback _MUST_ be called once
  callback()
end

return source
