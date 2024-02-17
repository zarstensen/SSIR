local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end

local cache_file = "prompt_cache.txt"

--- Static class representing a Split Stems prompt.
---@class SplitStemsPrompt
local P = {

    MODEL_OPTIONS = {
        "htdemucs (4 stems)",
        "htdemucs_ft (better quality than htdemucs, 4x as slow)",
        "htdemucs_6s (6 stems)",
        "htdemucs_mmi (newer model)",
        "mdx (MusDB dataset)",
        "mdx_extra (MusDB + training dataset)",
        "mdx_q (smaller version of mdx)",
        "mdx_extra_q (smaller version of mdx_extra)"
    },

    MODEL_VALUES = {
        [0] = "htdemucs",
        [1] = "htdemucs_ft",
        [2] = "htdemucs_6s",
        [3] = "htdemucs_mmi",
        [4] = "mdx",
        [5] = "mdx_extra",
        [6] = "mdx_q",
        [7] = "mdx_extra_q"
    },

    DEVICE_OPTIONS = {
        "CPU (slow, works on all hardware)",
        "Nvidia GPU (fast, only on nvidia hardware)",
    },

    DEVICE_VALUES = {
        [0] = "cpu",
        [1] = "nvidia",
    },

    ---@type fun(model: string, device: string) | nil
    SPLIT_STEMS_CALLBACK = nil,

    ---@type string
    SCRIPT_DIR = nil,
}

function P.loadCache()

    if not P.SCRIPT_DIR then
        return
    end

    local f = io.open(P.SCRIPT_DIR .. '/' .. cache_file, "r")

    if f == nil then
        return
    end

    local line = f:read("l")

    while line do

        local prop, val = line:match("%s*(.*)%s*=%s*(%d*)%s*")

        P[prop] = val

        line = f:read("l")
    end

    f:close()
end

function P.saveCache()

    if not P.SCRIPT_DIR then
        return
    end

    local f = io.open(P.SCRIPT_DIR .. '/' .. cache_file, "w")

    if not f then
        return
    end

    local cached_properties = { "model_value_index", "device_value_index" }

    for _, prop in ipairs(cached_properties) do
        f:write(prop .. "=" .. P[prop] .. '\n')
    end

    f:close()
end

--- Show the ImGui window, and prompt the user for stem and frequency selection.
function P.show()
    P.loadCache()
    P.ctx = ImGui.CreateContext("Zarstensen Scripts SSIR Prompt")

    ImGui.SetNextWindowSize(P.ctx, 300, 135, ImGui.Cond_Once())
    reaper.defer(P.guiLoop)
end

--- Helper function for ImGui.Combo.
---@param label string
---@param values string[] list of possible values
---@param value_index number selected value index
---@return number new_value_index
local function Combo(label, values, value_index)

    if not value_index then
        value_index = 0
    end

    local values_str = ""

    for _, val in ipairs(values) do
        values_str = values_str .. val .. "\0"
    end

    ---@type boolean, number
    local rv, v = ImGui.Combo(P.ctx, label, value_index, values_str)

    return v

end

--- Main loop drawing the imgui window.
function P.guiLoop()
    ---@type boolean, boolean
    local visible, open = ImGui.Begin(P.ctx, "Split Stems", true)

    if not open then
        ImGui.End(P.ctx)
        return
    end

    if not visible then
        reaper.defer(P.guiLoop)
        return
    end

    P.model_value_index = Combo('Model', P.MODEL_OPTIONS, P.model_value_index)
    P.device_value_index = Combo('Device', P.DEVICE_OPTIONS, P.device_value_index)

    P.saveCache()

    ImGui.NewLine(P.ctx)
    ImGui.NewLine(P.ctx)

    ---@type number
    local button_width = (ImGui.GetContentRegionAvail(P.ctx) - ImGui.GetWindowContentRegionMin(P.ctx)) / 2

    ---@type boolean
    local split_stems_clicked = ImGui.Button(P.ctx, 'Split Stems', button_width)
    ImGui.SameLine(P.ctx)
    ---@type boolean
    local cancelled_clicked = ImGui.Button(P.ctx, 'Cancel', button_width)

    ImGui.End(P.ctx)

    if cancelled_clicked then
        return
    end

    if split_stems_clicked and P.SPLIT_STEMS_CALLBACK then
        reaper.defer(function() P.SPLIT_STEMS_CALLBACK(P.MODEL_VALUES[P.model_value_index], P.DEVICE_VALUES[P.device_value_index]) end)
        return
    end


    reaper.defer(P.guiLoop)
end


return P
