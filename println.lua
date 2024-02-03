--- convert all arguments to string, and show them in a reaper console separated by tabs.
---@param ... any
local function println(...) 
    for i, v in ipairs({...}) do
      reaper.ShowConsoleMsg(string.format("%s\t", tostring(v)))
    end

    reaper.ShowConsoleMsg('\n')
end

return println
