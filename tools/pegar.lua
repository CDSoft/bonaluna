#!/usr/bin/env bl

--[[ BonaLuna executable generator

Copyright (C) 2010-2020 Christophe Delord
http://cdelord.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2017 Lua.org, PUC-Rio

Freely available under the terms of the MIT license.

--]]

do

    local START_SIG     = string.unpack("<I4", "GLUE")
    local END_SIG       = string.unpack("<I4", "#END")

    local LUA_BLOCK     = string.unpack("<I4", "#LUA")
    local STRING_BLOCK  = string.unpack("<I4", "#STR")
    local FILE_BLOCK    = string.unpack("<I4", "#RES")
    local DIR_BLOCK     = string.unpack("<I4", "#DIR")

    local z = z
    if not z then
        z = {}
        function z.compress(data) return data end
        function z.uncompress(data) return data end
    end

    local function min(s, ...)
        for i = 1, select("#", ...) do
            if #select(i, ...) < #s then
                s = select(i, ...)
            end
        end
        return s
    end

    function Pegar()

        local self = {}

        local _compress = 'min'
        local _compile  = 'min'

        function self.compress(mode) _compress = mode; return self end
        function self.compile(mode) _compile = mode; return self end

        local stub = nil      -- BonaLuna executable
        local glue = ""       -- additional blocks

        local log = function() end
        function self.verbose() log = print; return self end
        function self.quiet() log = function() end; return self end

        function self.read(exe)
            -- The default interpretor is the current executable
            exe = exe or arg[-1]
            log("read", exe)
            local f = assert(io.open(exe, "rb"))
            local data = assert(f:read "*a")
            f:close()
            local end_sig, size = string.unpack("I4I4", string.sub(data, #data-8+1))
            glue = string.pack("I4", START_SIG)
            if end_sig ~= END_SIG then
                log("", exe.." is empty")
                stub = data
                return self
            end
            stub = string.sub(data, 1, #data-size)
            data = string.sub(data, #data-size+1)
            local start_sig = string.unpack("I4", data)
            if start_sig ~= START_SIG then error("Unrecognized start signature in "..exe) end
            data = string.sub(data, 4+1)
            while #data > 8 do
                local block_type, name_len, data_len, name = string.unpack("I4I4I4z", data)
                if block_type == LUA_BLOCK then log("", "lua", name)
                elseif block_type == STRING_BLOCK then log("", "str", name)
                elseif block_type == FILE_BLOCK then log("", "file", name)
                elseif block_type == DIR_BLOCK then log("", "dir", name)
                else error("Unrecognized block in "..exe) end
                glue = glue .. string.sub(data, 1, 4*3+name_len+data_len)
                data = string.sub(data, 4*3+name_len+data_len+1)
            end
            local end_sig, size = string.unpack("I4I4", string.sub(data, #data-8))
            if end_sig ~= END_SIG then error("Unrecognized end signature in "..exe) end
            if size ~= #glue+4*2 then error("Invalid size in "..exe) end
            return self
        end

        function self.write(exe)
            log("write", exe)
            if not stub then self.read() end
            local f = assert(io.open(exe, "wb"))
            assert(f:write(stub))
            assert(f:write(glue))
            assert(f:write(string.pack("I4I4", END_SIG, #glue+4*2)))
            f:close()
            fs.chmod(exe, fs.aR, fs.aX, fs.uW)
            return self
        end

        function self.lua(script_name, real_name)
            log("lua", script_name)
            if not stub then self.read() end
            local f = assert(io.open(real_name or script_name, "rb"))
            local content = assert(f:read "*a")
            f:close()
            content = content:gsub("^#!.-([\r\n])", "%1")  -- load doesn't like "#!..."
            local compiled_content = assert(string.dump(assert(load(content, script_name))))
            local compressed_content = z.compress(content) or content
            local compressed_compiled_content = z.compress(compiled_content) or compiled_content

            local smallest = {
                off = {
                    off = content,
                    on = compressed_content,
                    min = min(content, compressed_content),
                },
                on = {
                    off = compiled_content,
                    on = compressed_compiled_content,
                    min = min(compiled_content, compressed_compiled_content),
                },
                min = {
                    off = min(content, compiled_content),
                    on = min(compressed_content, compressed_compiled_content),
                    min = min(content, compiled_content, compressed_content, compressed_compiled_content),
                },
            }

            content = smallest[_compile][_compress]

            glue = glue .. string.pack("I4I4I4zc"..#content, LUA_BLOCK, #script_name+1, #content, script_name, content)
            return self
        end

        function self.str(name, value)
            log("str", name)
            if not stub then self.read() end
            local compressed_value = z.compress(value) or value
            local smallest = {
                off = value,
                on = compressed_value,
                min = min(value, compressed_value),
            }
            value = smallest[_compress]
            glue = glue .. string.pack("I4I4I4zc"..#value, STRING_BLOCK, #name+1, #value, name, value)
            return self
        end

        function self.strf(name, file)
            log("str", name)
            if not stub then self.read() end
            local f = assert(io.open(file, "rb"))
            local value = assert(f:read "*a")
            f:close()
            return self.str(name, value)
        end

        function self.file(name, real)
            log("file", name)
            if not stub then self.read() end
            local f = assert(io.open(real or name, "rb"))
            local content = assert(f:read "*a")
            f:close()
            local compressed_content = z.compress(content) or content
            local smallest = {
                off = content,
                on = compressed_content,
                min = min(content, compressed_content),
            }
            content = smallest[_compress]
            glue = glue .. string.pack("I4I4I4zc"..#content, FILE_BLOCK, #name+1, #content, name, content)
            return self
        end

        function self.dir(name)
            log("dir", name)
            if not stub then self.read() end
            glue = glue .. string.pack("I4I4I4z", DIR_BLOCK, #name+1, 0, name)
            return self
        end

        return self
    end

end

local usage = [[
usage: ]]..(arg[0] or arg[1] or arg[-1])..[[ arguments

    -q  quiet
    -v  verbose

    compile:on              turn compilation on
    compile:off             turn compilation off
    compile:min             turn compilation on when chunks are smaller than sources
    compress:on             turn compression on
    compress:off            turn compression off
    compress:min            turn compression on when chunks are smaller than sources

    read:bl.exe             read bl.exe and its current glue
    lua:script.lua          add a new script
    lua:script.lua=realname add a new script with a different name
    str:name="some text"    add a global variable name
    str:name=@filename      add a global variable, the value is in a file
    file:name               add a file (same name in the glue)
    file:name=realname      add a file with name 'name', the content is in a file
    dir:name                create a directory
    write:bl2.exe           write a new executable

example:
    bl pegar.lua read:bl.exe lua:pegar.lua write:pegar.exe
        glues bl.exe and pegar.lua into a self-running pegar.exe executable

pegar means to glue in Occitan.
]]

if #arg == 0 then
    print(usage)
    os.exit()
end

local exe = Pegar().verbose()

for i, cmd in ipairs(arg) do
    if cmd == '-q' then exe.quiet()
    elseif cmd == '-v' then exe.verbose()
    else
        local action, param = string.match(cmd, "^(%w+):(.*)$")
        local param1, param2 = string.match(param, "^(.-)=(.+)$")
        if action == "compile" and (param == 'min' or param == 'on' or param == 'off') then exe.compile(param)
        elseif action == "compress" and (param == 'min' or param == 'on' or param == 'off') then exe.compress(param)
        elseif action == "read" then exe.read(param)
        elseif action == "write" then exe.write(param)
        elseif action == "lua" then exe.lua(param1 or param, param2)
        elseif action == "str" and param2 then
            if string.match(param2, "^@") then exe.strf(param1, string.sub(param2, 2))
            else exe.str(param1, param2)
            end
        elseif action == "file" then exe.file(param1 or param, param2)
        elseif action == "dir" then exe.dir(param)
        else error("Unrecognized parameter: "..cmd) end
    end
end
