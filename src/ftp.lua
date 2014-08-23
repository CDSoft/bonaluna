--[[ FTP library

Copyright (C) 2010-2014 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2013 Lua.org, PUC-Rio

Freely available under the terms of the Lua license.

--]]

function FTP(url, user, password)
    local ftp = {}
    local t = socket.url.parse(url)
    if user then t.user = user end
    if password then t.password = password end

    local open = socket.protect(function()
        local f = socket.ftp.open(t.host, t.port, t.create)
        f:greet()
        f:login(t.user, t.password)
        return f
    end)

    local f, err = open()
    if not f then return nil, err end

    ftp.close = socket.protect(function()
        f:quit()
        return f:close()
    end)

    ftp.cd = socket.protect(function(path)
        f:pasv()
        return f:cwd(path)
    end)

    ftp.pwd = socket.protect(function()
        f.try(f.tp:command("PWD"))
        local code, path = f.try(f.tp:check{257})
        if not code then return code, path end
        return (path:gsub('^[^"]*"(.*)"[^"]*$', "%1"))
    end)

    ftp.get = socket.protect(function(path)
        local t = {}
        f:pasv()
        f:receive{path=path, command="RETR", sink=ltn12.sink.table(t)}
        return table.concat(t)
    end)

    ftp.put = socket.protect(function(path, data)
        local partial = path..".part"
        f:pasv()
        local sent = f:send{path=partial, command="STOR", source=ltn12.source.string(data)}
        f:pasv()
        f.try(f.tp:command("RNFR", partial))
        f.try(f.tp:check{350})
        f.try(f.tp:command("RNTO", path))
        f.try(f.tp:check{250})
        return sent
    end)

    ftp.rm = socket.protect(function(path)
        f.try(f.tp:command("DELE", path))
        return f.try(f.tp:check{250})
    end)

    ftp.mkdir = socket.protect(function(path)
        f.try(f.tp:command("MKD", path))
        return f.try(f.tp:check{257})
    end)

    ftp.rmdir = socket.protect(function(path)
        f.try(f.tp:command("RMD", path))
        return f.try(f.tp:check{250})
    end)

    ftp.list = socket.protect(function(path)
        local t = {}
        f:pasv()
        f:receive{path=(path or "."), command="LIST", sink=ltn12.sink.table(t)}
        local files = {}
        for line in table.concat(t):gmatch("[^\r\n]+") do
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
    end)

    -- TODO: ftp.walk (as fs.walk)

    return ftp
end
