local Directory = require 'Directory'

--- Class responsible for splitting a media source into it stems using spleeter, and inserting them back into reaper.
---@class SplitStems
local P = {}

--- Create a new SplitStems object, for a specific stem split configuration.
---@param script_dir string directory to place any downloaded models and temporarily store extracted stems.
---@param selected_media MediaItem 
---@param selected_track MediaTrack
---@param stems number
---@param is_16_khz boolean
---@return table
function P.new(script_dir, selected_media, selected_track, stems, is_16_khz)
    local obj = {}
    P.__index = P
    setmetatable(obj, P)

    obj.script_dir = script_dir
    obj.selected_media = selected_media
    obj.selected_track = selected_track
    obj.stems = stems
    obj.is_16_khz = is_16_khz

    obj.media_file = reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(obj.selected_media, 0)))
    obj.spleeter_dst_path = obj.script_dir .. 'spleeter_out/' .. obj.media_file:match([[.*\(.*)%..*]]) .. '/'
    obj.stem_path = reaper.GetProjectPath() .. '/' .. obj.media_file:match([[.*\(.*)%..*]]) .. '/'

    return obj
end

--- start spleeter in a separate background process, and wait for it to finish before inserting the stems.
function P:beginSplitting()

    -- make sure any previous stems are removed, as we use this for checking when spleeter has finished processing.

    Directory.removeContents(self.spleeter_dst_path, 1)
    Directory.removeContents(self.stem_path, 1)

    reaper.ExecProcess(string.format("\"%s/run-spleeter.bat\" \"%s\" \"%s\" \"%istems%s\" \"%s\"",
    self.script_dir,
    self.script_dir,
    self.media_file,
    self.stems,
    self.is_16_khz and "-16khz" or "",
    reaper.GetResourcePath() .. '/Data/SSIRSpleeterEnv.tar.gz'),
    -2)
    
    -- periodically check if spleeter has finished, without blocking reaper.
    reaper.defer(function() self:waitForSplitEnd() end)
end

function P:waitForSplitEnd()
    reaper.EnumerateFiles(self.spleeter_dst_path, -1)
  
    -- stem files have not yet been created
    if not reaper.EnumerateFiles(self.spleeter_dst_path, self.stems - 1) then
      reaper.defer(function() self:waitForSplitEnd() end)
      return
    end
    -- wait a bit, to make sure the files have finished writing to disk.

    local wait_s = os.clock() + 1
    while (os.clock() < wait_s) do end

    -- files exist at this point

    reaper.defer(function() self:importStemTracks() end)
end

--- called when spleeter has finished extracting stem parts.
--- primarily responsible for inserting the stems into the project.
---
--- new stems are placed in a folder named after the originally selected track,
--- where each track in the folder is a stem from the original media item.
function P:importStemTracks()
    -- move split stems to project folder
    Directory.move(self.spleeter_dst_path, reaper.GetProjectPath())

    reaper.SetMediaItemInfo_Value(self.selected_media, "B_MUTE", 1)


    -- create top level folder track

    ---@type number
    local target_index = reaper.GetMediaTrackInfo_Value(self.selected_track, "IP_TRACKNUMBER")
    ---@type any, string
    local _, target_track_name = reaper.GetSetMediaTrackInfo_String(self.selected_track, "P_NAME", "", false)

    reaper.InsertTrackAtIndex(target_index, false)
    ---@type MediaTrack
    local folder_track = reaper.GetTrack(0, target_index)

    reaper.GetSetMediaTrackInfo_String(folder_track, "P_NAME", target_track_name .. " - stems", true)

    -- collapse folder track, as it does not contain anything important itself.
    reaper.SetMediaTrackInfo_Value(folder_track, "I_HEIGHTOVERRIDE", 1)

    -- move cursor to start of selected media, so the imported stem files line up with the original audio clip.

    ---@type number
    local insert_pos = reaper.GetMediaItemInfo_Value(self.selected_media, "D_POSITION")
    reaper.SetEditCurPos2(0, insert_pos, false, false)

    -- now add each stem media file as its own child track to the folder track

    local file_index = 0

    while true do
        ---@type number
        local file = reaper.EnumerateFiles(self.stem_path, file_index)
        
        if not file then
            break
        end
        
        local stem_track_index = target_index + file_index + 1
        local file_name = file:match([[(.*)%..*]])
        file = self.stem_path .. '/' .. file
        
        reaper.InsertTrackAtIndex(stem_track_index, false)
        ---@type MediaTrack
        local file_track = reaper.GetTrack(0, stem_track_index)
        
        reaper.GetSetMediaTrackInfo_String(file_track, "P_NAME", file_name, true)
        
        -- insert the media at the newly created track, since we want to specify the track id,
        -- we need to set the 9'th bit in the mode apram, and set the hiword (last 16 bits) to the index of the target track.
        reaper.InsertMedia(file, (stem_track_index << 16) | (1 << 9))
        
        file_index = file_index + 1
    end

    -- finally, make sure all the newly added tracks are contained inside the folder track
    reaper.SetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH", 1, true)
    reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, target_index + file_index), "I_FOLDERDEPTH", -1, true)

    reaper.TrackList_AdjustWindows(target_index)
end


return P
