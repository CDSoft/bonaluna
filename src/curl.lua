--[[ BonaLuna cURL interface

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

function curl.FTP(url, login, pass)
    local ftp = {}
    local server
    if login then
        server = string.format("ftp://%s:%s@%s", login, pass, url)
    else
        server = string.format("ftp://%s", url)
    end
    local wd = "/"

    function ftp.cd(path)
        if path == ".." then
            wd = fs.dirname(path).."/"
        else
            if not path:match("/$") then path = path .. "/" end
            wd = wd..path
        end
    end

    function ftp.get(path)
        if not path:match("^/") then path = wd..path end
        local c = curl.easy_init()
        c:setopt_url(server..path)
        local buffer = {}
        local ok, err = c:perform{writefunction=function(data)
            table.insert(buffer, data)
            return #data
        end}
        if ok then
            return table.concat(buffer)
        else
            return ok, err
        end
    end

    function ftp.put(path, data)
        if not path:match("^/") then path = wd..path end
        local tmp_path = path.."-uploading"
        local c = curl.easy_init()
        c:setopt_url(server..tmp_path)
        c:setopt_upload(1)
        c:setopt_infilesize(#data)
        c:setopt_postquote{"RNFR "..tmp_path, "RNTO "..path}
        local index = 1
        return c:perform{readfunction=function(size)
            local chunk = data:sub(index, index+size-1)
            index = index + size
            return chunk
        end}
    end

    function ftp.del(path)
        if not path:match("^/") then path = wd..path end
        local c = curl.easy_init()
        c:setopt_url(server..path)
        c:setopt_postquote("DELE "..path)
        return c:perform{writefunction=function() end}
    end

    function ftp.mkdir(path)
        if not path:match("^/") then path = wd..path end
        local c = curl.easy_init()
        c:setopt_url(server..path)
        c:setopt_quote("MKD "..path)
        return c:perform{writefunction=function() end}
    end

    function ftp.rmdir(path)
        if not path:match("^/") then path = wd..path end
        local c = curl.easy_init()
        c:setopt_url(server..path.."/")
        c:setopt_postquote{"CWD "..fs.dirname(path), "RMD "..fs.basename(path)}
        return c:perform{writefunction=function() end}
    end

    function ftp.list(path)
        path = path or "."
        if not path:match("^/") then path = wd..path end
        if not path:match("/$") then path = path.."/" end
        local c = curl.easy_init()
        c:setopt_url(server..path)
        local buffer = {}
        local ok, err = c:perform{writefunction=function(data)
            table.insert(buffer, data)
            return #data
        end}
        if not ok then return ok, err end
        buffer = table.concat(buffer)
        local files = {}
        for line in buffer:gmatch("[^\r\n]+") do
            local dir, size, name = line:match "([d-])[rwx-]+%s+%d+%s+%w+%s+%w+%s+(%d+)%s+%w+%s+%w+%s+[%w:]+%s+(.*)"
            if not name:match("^%.%.?$") then
                if dir == "d" then table.insert(files, {name, dir})
                else table.insert(files, {name, tonumber(size)})
                end
            end
        end
        local i = 0
        return function()
            i = i+1
            if files[i] then
                return table.unpack(files[i])
            end
        end
    end

    return ftp
end
