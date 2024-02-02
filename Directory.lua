local println = require 'println'

---@class Directory
local P = {}

--- Move the 1'st level contents of the passed directory to a new destination folder.
--- Original folder is not deleted, as windows does not allow this, folder contents are.
---@param directory string
---@param dest string
function P.move(directory, dest)
    local dir_name = directory:match(".*[\\/]+(.*)[\\/]") .. '/'

    -- create destination directory

    dest = dest .. '/' .. dir_name

    os.execute(string.format('mkdir \"%s\"', dest))

    -- copy files from current directory to new directory.

    reaper.EnumerateFiles(directory, -1)

    local file_index = 0

    while reaper.EnumerateFiles(directory, file_index) do
        ---@type string
        local file_name = reaper.EnumerateFiles(directory, file_index)
        local file = directory .. file_name

        local src_file = io.open(file, 'rb')
        local dest_file = io.open(dest .. file_name, 'wb')

        dest_file:write(src:read("*a"))

        src_file:close()
        dest_file:close()

        file_index = file_index + 1
    end

    P.removeContents(directory, 1)
end

--- Remove all file contents of the passed directory, to a specified depth.
--- Does not delete folders themselves, as windows does not allow this with os.remove.
---@param directory string
---@param max_depth number
function P.removeContents(directory, max_depth)

    if max_depth <= 0 then
        return
    end

    -- refresh cache

    reaper.EnumerateFiles(directory, -1)
    reaper.EnumerateSubdirectories(directory, -1)

    -- loop over subdirectories

    local subdir_index = 0

    while reaper.EnumerateSubdirectories(directory, subdir_index) do
        ---@type string
        local subdir = reaper.EnumerateSubdirectories(directory, subdir_index)
        P.removeContents(directory .. subdir .. '/', max_depth - 1)
        subdir_index = subdir_index + 1
    end

    -- remove all files in current directory

    local file_index = 0

    while reaper.EnumerateFiles(directory, file_index) do
        ---@type string
        local file = reaper.EnumerateFiles(directory, file_index)
        println("REMOVING ", file)
        local res, err = os.remove(directory .. file)

        println(res or 'NIL', err)

        file_index = file_index + 1
    end
end

return P
