#!/usr/bin/env bl

--[[ BonaLuna executable generator

Copyright (C) 2010-2013 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

usage = [[
usage: ]]..arg[-1]..[[ ]]..arg[0]..[[ arguments

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

START_SIG       = 0x45554C47
END_SIG         = 0x444E4523

LUA_BLOCK       = 0x41554C23
STRING_BLOCK    = 0x52545323
FILE_BLOCK      = 0x53455223
DIR_BLOCK       = 0x52494423

compress        = 'min'
compile         = 'min'

stub = nil      -- BonaLuna executable
glue = ""       -- additional blocks

verbose = true

function log(...)
    if verbose then
        print(...)
    end
end

function err(...)
    print(...)
    os.exit(1)
end

if not z then
    z = {}
    function z.compress(data) return data end
    function z.uncompress(data) return data end
end

function do_read(exe)
    local f = assert(io.open(exe, "rb"))
    local data = assert(f:read "*a")
    f:close()
    local end_sig, size = struct.unpack("I4I4", string.sub(data, #data-8+1))
    glue = struct.pack("I4", START_SIG)
    if end_sig ~= END_SIG then
        log("", exe.." is empty")
        stub = data
        return
    end
    stub = string.sub(data, 1, #data-size)
    data = string.sub(data, #data-size+1)
    local start_sig = struct.unpack("I4", data)
    if start_sig ~= START_SIG then err("Unrecognized start signature in "..exe) end
    data = string.sub(data, 4+1)
    while #data > 8 do
        local block_type, name_len, data_len, name = struct.unpack("I4I4I4s", data)
        if block_type == LUA_BLOCK then log("", "lua", name)
        elseif block_type == STRING_BLOCK then log("", "str", name)
        elseif block_type == FILE_BLOCK then log("", "file", name)
        elseif block_type == DIR_BLOCK then log("", "dir", name)
        else err("Unrecognized block in "..exe) end
        glue = glue .. string.sub(data, 1, 4*3+name_len+data_len)
        data = string.sub(data, 4*3+name_len+data_len+1)
    end
    local end_sig, size = struct.unpack("I4I4", string.sub(data, #data-8))
    if end_sig ~= END_SIG then err("Unrecognized end signature in "..exe) end
    if size ~= #glue+4*2 then err("Invalid size in "..exe) end
end

function do_write(exe)
    local f = assert(io.open(exe, "wb"))
    assert(f:write(stub))
    assert(f:write(glue))
    assert(f:write(struct.pack("I4I4", END_SIG, #glue+4*2)))
    f:close()
    fs.chmod(exe, fs.aR, fs.aX, fs.uW)
end

function min(s, ...)
    for i = 1, select("#", ...) do
        if #select(i, ...) < #s then
            s = select(i, ...)
        end
    end
    return s
end

function do_lua(name)
    local script_name, real_name = string.match(name, "^(.+)=(.+)$")
    if not script_name then script_name = name real_name = name end

    local f = assert(io.open(real_name, "rb"))
    local content = assert(f:read "*a")
    f:close()
    content = content:gsub("^#!.-([\r\n])", "%1")  -- load doesn't like "#!..."
    local compiled_content = assert(string.dump(assert(load(content, script_name))))
    local compressed_content = z.compress(content) or content
    local compressed_compiled_content = z.compress(compiled_content) or compiled_content

    --print(string.rep("-", 50))
    --print("content                    ", #content)
    --print("compiled_content           ", #compiled_content)
    --print("compressed_content         ", #compressed_content)
    --print("compressed_compiled_content", #compressed_compiled_content)

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

    content = smallest[compile][compress]

    --print("compile", compile, "compress", compress, "=>", #content)

    glue = glue .. struct.pack("I4I4I4sc0", LUA_BLOCK, #script_name+1, #content, script_name, content)
end

function do_str(name_value)
    local name, value = string.match(name_value, "^([%w_]+)=(.*)$")
    if not name then err("Invalid string") end
    if string.sub(value, 1, 1) == "@" then
        local f = assert(io.open(string.sub(value, 2), "rb"))
        value = assert(f:read "*a")
        f:close()
    end
    local compressed_value = z.compress(value) or value
    local smallest = {
        off = value,
        on = compressed_value,
        min = min(value, compressed_value),
    }
    value = smallest[compress]
    glue = glue .. struct.pack("I4I4I4sc0", STRING_BLOCK, #name+1, #value, name, value)
end

function do_file(name)
    local filename, realname = string.match(name, "^(.+)=(.+)$")
    if not filename then filename=name realname=name end
    local f = assert(io.open(realname, "rb"))
    local content = assert(f:read "*a")
    f:close()
    local compressed_content = z.compress(content) or content
    local smallest = {
        off = content,
        on = compressed_content,
        min = min(content, compressed_content),
    }
    content = smallest[compress]
    glue = glue .. struct.pack("I4I4I4sc0", FILE_BLOCK, #filename+1, #content, filename, content)
end

function do_dir(name)
    glue = glue .. struct.pack("I4I4I4s", DIR_BLOCK, #name+1, 0, name)
end

if #arg == 0 then
    print(usage)
    os.exit()
end

for i, cmd in ipairs(arg) do
    if cmd == '-q' then verbose = false
    elseif cmd == '-v' then verbose = true
    else
        action, param = string.match(cmd, "^(%w+):(.*)$")
        log(action, param)
        if action == "compile" and (param == 'min' or param == 'on' or param == 'off') then compile = param
        elseif action == "compress" and (param == 'min' or param == 'on' or param == 'off') then compress = param
        elseif action == "read" then do_read(param)
        elseif action == "write" then do_write(param)
        elseif action == "lua" then do_lua(param)
        elseif action == "str" then do_str(param)
        elseif action == "file" then do_file(param)
        elseif action == "dir" then do_dir(param)
        else err("Unrecognized parameter: "..cmd) end
    end
end
