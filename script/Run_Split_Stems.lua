-- check all ReaPack dependencies are installed.

---@type table<string, fun(): boolean>
local dependencies = {
  [ '"ReaImGui"' ] = function()
      return true and reaper.ImGui_GetVersion or false
  end
}

---@type string[]
local missing_dependencies = { }

for dependency, is_installed in pairs(dependencies) do
  if not is_installed() then
    table.insert(missing_dependencies, dependency)
  end
end

if #missing_dependencies > 0 then
  reaper.ShowMessageBox("Some dependencies are needed for this plugin to work.\nPlease install all packages in next window.", "Missing Dependencies!", 0)
  reaper.ReaPack_BrowsePackages(table.concat(missing_dependencies, " OR "))
  return
end

-- all dependencies are accounted for now.

-- add plugin folder to lua import search path

---@type string

local _is_new_value, filename, _sectionID, _cmdID, _mode, _resolution, _val, _contextstr = reaper.get_action_context()

local plugin_dir = filename:match("(.*)[/\\].*..*")
package.path = package.path .. ";" .. plugin_dir .. "/?.lua"

-- import internal lua packages

local SplitStemsPrompt = require 'SplitStemsPrompt'
local SplitStems = require 'SplitStems'
local println = require 'println'

local selected_media_item = reaper.GetSelectedMediaItem(0, 0)
local selected_track = reaper.GetLastTouchedTrack()

if not selected_media_item or not selected_track then
  -- 4'th bit = toggle err.
  reaper.ShowMessageBox("You must select a media source and track!", "SSIR Script Failure", (1 << 4) | 0)
  return
end

SplitStemsPrompt.SCRIPT_DIR = plugin_dir
SplitStemsPrompt.SPLIT_STEMS_CALLBACK = function(model, device)
  local split_stems = SplitStems.new(plugin_dir, selected_media_item, selected_track, model, device)
  split_stems:beginSplitting()
end

SplitStemsPrompt.show()
