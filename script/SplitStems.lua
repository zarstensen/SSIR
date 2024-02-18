local println = require 'println'

local tcp_port_file = "tcp_port.txt"

--- Class responsible for splitting a media source into it stems using spleeter, and inserting them back into reaper.
---@class SplitStems
local P = {}

--- Create a new SplitStems object, for a specific stem split configuration.
---@param script_dir string directory to place any downloaded models and temporarily store extracted stems.
---@param selected_media MediaItem 
---@param selected_track MediaTrack
---@param model string
---@param device string
---@return table
function P.new(script_dir, selected_media, selected_track, model, device)
    local obj = {}
    P.__index = P
    setmetatable(obj, P)

    obj.script_dir = script_dir
    obj.selected_media = selected_media
    obj.selected_track = selected_track
    obj.model = model
    obj.device = device

    obj.port = nil

    obj.media_file = reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(obj.selected_media, 0)))
    obj.stem_path = reaper.GetProjectPath() .. '/separated/' .. obj.model .. '/' .. obj.media_file:match([[.*\(.*)%..*]]) .. '/'

    return obj
end

--- start spleeter in a separate background process, and wait for it to finish before inserting the stems.
function P:beginSplitting()

    -- make sure any previous stems are removed, as we use this for checking when spleeter has finished processing.
    
    -- refresh cache

    reaper.EnumerateFiles(self.stem_path, -1)
    reaper.EnumerateSubdirectories(self.stem_path, -1)

    -- remove all files in current directory

    local file_index = 0

    while reaper.EnumerateFiles(self.stem_path, file_index) do
        local file = reaper.EnumerateFiles(self.stem_path, file_index)
        os.remove(self.stem_path .. file)
        file_index = file_index + 1
    end


    local tcp_port_file_path = self.script_dir .. '/' .. tcp_port_file

    -- remove previous tcp port file in case it was not removed.
    os.remove(tcp_port_file_path)

    reaper.ExecProcess(string.format("\"%s/run_demucs\" \"%s\" begin \"%s\" %s %s \"%s\" \"%s\"",
    self.script_dir,
    self.script_dir,
    self.media_file,
    self.model,
    self.device,
    self.script_dir .. '/' .. 'demucs_env.tar.gz',
    reaper.GetProjectPath() .. '/separated'),
    -2)
    
    -- wait until port has been written to disk, so we know where the tcp server is hosted at.

    while not self.port do
        local f = io.open(tcp_port_file_path)
        
        if f then
            self.port = f:read("l")
            f:close()
            os.remove(tcp_port_file_path)
        end
    end

    -- periodically check if spleeter has finished, without blocking reaper.
    reaper.defer(function() self:waitForSplitEnd() end)
end

function P:waitForSplitEnd()

    local ret = reaper.ExecProcess(string.format("\"%s/run_demucs\" \"%s\" check %s",
        self.script_dir,
        self.script_dir,
        self.port),
        0)
    
    ret = tonumber(ret:match("(%d+)%c+.*"))

    if ret == 0 then
        reaper.defer(function() self:waitForSplitEnd() end)
        return
    end

    if ret ~= 1 then
        println("ERROR: ", ret)
        return
    end

    println("WE DIT ID!!!")

    reaper.defer(function() self:importStemTracks() end)
end

--- called when spleeter has finished extracting stem parts.
--- primarily responsible for inserting the stems into the project.
---
--- new stems are placed in a folder named after the originally selected track,
--- where each track in the folder is a stem from the original media item.
function P:importStemTracks()
    reaper.SetMediaItemInfo_Value(self.selected_media, "B_MUTE", 1)
    println(self.stem_path)

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
