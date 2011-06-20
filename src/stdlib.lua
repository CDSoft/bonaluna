--[[ BonaLuna standard libraries

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

-- This is an addendum to the C-coded libraries

function fs.walk(path)
    local dirs = {path or "."}
    local files = {}
    return function()
        if #files > 0 then
            return table.remove(files, 1)
        elseif #dirs > 0 then
            local dir = table.remove(dirs)
            local names = fs.dir(dir)
            if names then
                table.sort(names)
                for i = 1, #names do
                    local name = dir..fs.sep..names[i]
                    if fs.stat(name).type == "directory" then
                        table.insert(dirs, name)
                    else
                        table.insert(files, name)
                    end
                end
                return dir
            end
        end
    end
end
