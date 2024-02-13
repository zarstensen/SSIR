local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end


--- Static class representing a Split Stems prompt.
---@class SplitStemsPrompt
local P = {

    STEMS_OPTIONS = {
        "2 Stems (vocals, accompaniment)",
        "4 Stems (vocals, bass, drums, other)",
        "5 Stems (vocals, drums, bass, piano, other)",
    },

    STEMS_VALUES = {
        [0] = 2,
        [1] = 4,
        [2] = 5,
    },

    FREQ_OPTIONS = {
        "11 Khz",
        "16 Khz",
    },

    IS_16KHZ_VALUES = {
        [0] = false,
        [1] = true,
    },

    ---@type fun(stems: number, is_16_khz: boolean) | nil
    SPLIT_STEMS_CALLBACK = nil,
}

--- Show the ImGui window, and prompt the user for stem and frequency selection.
function P.show()

    P.ctx = ImGui.CreateContext("Zarstensen Scripts SSIR Prompt")

    ImGui.SetNextWindowSize(P.ctx, 400, 400, ImGui.Cond_FirstUseEver())
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
    local visible, open = ImGui.Begin(P.ctx, "ImGui Window", true)

    if not open then
        ImGui.End(P.ctx)
        return
    end

    if not visible then
        reaper.defer(P.guiLoop)
        return
    end

    P.stems_value_index = Combo('Stems', P.STEMS_OPTIONS, P.stems_value_index)
    P.freq_value_index = Combo('Max Freq', P.FREQ_OPTIONS, P.freq_value_index)

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
        reaper.defer(function() P.SPLIT_STEMS_CALLBACK(P.STEMS_VALUES[P.stems_value_index], P.IS_16KHZ_VALUES[P.freq_value_index]) end)
        return
    end

    reaper.defer(P.guiLoop)
end


return P
