local function println(...)
    
    for i, v in ipairs({...}) do
      reaper.ShowConsoleMsg(string.format("%s\t", tostring(v)))
    end
    
    reaper.ShowConsoleMsg('\n')
end

local function getTargetMedia()
  local selected_media_item = reaper.GetSelectedMediaItem(0, 0)
  
  if not selected_media_item then
    return nil
  end
  
  local media_source_name = reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(selected_media_item, 0)))
  
  return selected_media_item, media_source_name
end

local function beginStemSplitting(script_dir, media_file)
  reaper.ExecProcess(string.format("\"%s/run-spleeter.bat\" \"%s\" \"%s\"", script_dir, script_dir, media_file), -2)
end

local function importStemTracks(target_track, source_media, stem_path)
  
  -- create top level folder track
  
  local target_index = reaper.GetMediaTrackInfo_Value(target_track, "IP_TRACKNUMBER")
  local _, target_track_name = reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "", false)
  
  reaper.InsertTrackAtIndex(target_index, false)
  local folder_track = reaper.GetTrack(0, target_index)
  
  reaper.GetSetMediaTrackInfo_String(folder_track, "P_NAME", target_track_name .. " - stems", true)
  
  -- collapse folder track, as it does not contain anything important itself.
  reaper.SetMediaTrackInfo_Value(folder_track, "I_HEIGHTOVERRIDE", 1)
  
  -- move cursor to start of selected media, so the imported stem files line up with the original audio clip.
  
  local insert_pos = reaper.GetMediaItemInfo_Value(source_media, "D_POSITION")
  reaper.SetEditCurPos2(0, insert_pos, false, false)
  
  -- now add each stem media file as its own child track to the folder track
  
  local file_index = 0
  
  while true do
    local file = reaper.EnumerateFiles(stem_path, file_index)
    
    if not file then
      break
    end
    
    local stem_track_index = target_index + file_index + 1
    local file_name = file:match([[(.*)%..*]])
    file = stem_path .. '/' .. file
    
    reaper.InsertTrackAtIndex(stem_track_index, false)
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

local function onStemSplittingDone()
  reaper.EnumerateFiles(MediaPath, -1)

  -- stem files have not yet been created
  if not reaper.EnumerateFiles(MediaPath, 3) then
    reaper.defer(onStemSplittingDone)
    return
  end
  
  -- files exist at this point
  
  reaper.SetMediaItemInfo_Value(SelectedMediaItem, "B_MUTE", 1)
  
  importStemTracks(SelectedTrack, SelectedMediaItem, MediaPath)
  
end

local _is_new_value, script_file_name, _section_id, _cmd_id, _mode, _resolution, _val, _contextstr = reaper.get_action_context()
ScriptDir = script_file_name:match([[(.*)\.*]])

SelectedMediaItem, MediaSourceName = getTargetMedia()
SelectedTrack = reaper.GetLastTouchedTrack()
MediaPath = ScriptDir .. '/spleeter_out/' .. MediaSourceName:match([[.*\(.*)%..*]])

if not SelectedMediaItem or not SelectedTrack then
  println("FAILURE")
  return
end

beginStemSplitting(ScriptDir, MediaSourceName)
reaper.defer(onStemSplittingDone)
