#!/usr/bin/env bl

usage = [[
glue.lua usage:

    read:bl.exe             read bl.exe and its current glue
    lua:script.lua          add a new script
    lua:script.lua=realname add a new script with a different name
    str:name="some text"    add a global variable name
    str:name=@filename      add a global variable, the value is in a file
    file:name               add a file (same name in the glue)
    file:name=realname      add a file with name 'name', the content is in a file
    dir:name                create a directory
    write:bl2.exe           write a new executable
]]

START_SIG       = 0x474C5545
END_SIG         = 0x23454E44

LUA_BLOCK       = 0x234C5541
STRING_BLOCK    = 0x23535452
FILE_BLOCK      = 0x23524553
DIR_BLOCK       = 0x23444952

compile = true -- also define COMPILE in glue.c

stub = nil      -- BonaLuna executable
glue = ""       -- additional blocks

function do_read(exe)
    local f = assert(io.open(exe, "rb"))
    local data = assert(f:read "*a")
    f:close()
    local end_sig, size = struct.unpack("I4I4", string.sub(data, #data-8+1))
    glue = struct.pack("I4", START_SIG)
    if end_sig ~= END_SIG then
        print("", exe.." is empty")
        stub = data
        return
    end
    stub = string.sub(data, 1, #data-size)
    data = string.sub(data, #data-size+1)
    local start_sig = struct.unpack("I4", data)
    if start_sig ~= START_SIG then
        print("Unrecognized start signature in "..exe)
        os.exit(1)
    end
    data = string.sub(data, 4+1)
    while #data > 8 do
        local block_type, name_len, data_len, name = struct.unpack("I4I4I4s", data)
        if block_type == LUA_BLOCK then print("", "lua", name)
        elseif block_type == STRING_BLOCK then print("", "str", name)
        elseif block_type == FILE_BLOCK then print("", "file", name)
        elseif block_type == DIR_BLOCK then print("", "dir", name)
        else
            print("Unrecognized block in "..exe)
            os.exit(1)
        end
        glue = glue .. string.sub(data, 1, 4*3+name_len+data_len)
        data = string.sub(data, 4*3+name_len+data_len+1)
    end
    local end_sig, size = struct.unpack("I4I4", string.sub(data, #data-8))
    if end_sig ~= END_SIG then
        print("Unrecognized end signature in "..exe)
        os.exit(1)
    end
    if size ~= #glue+4*2 then
        print("Invalid size in "..exe)
        os.exit(1)
    end
end

function do_write(exe)
    local f = assert(io.open(exe, "wb"))
    assert(f:write(stub))
    assert(f:write(glue))
    assert(f:write(struct.pack("I4I4", END_SIG, #glue+4*2)))
    f:close()
    fs.chmod(exe, fs.aR, fs.aX, fs.uW)
end

function do_lua(name)
    local script_name, real_name = string.match(name, "^(.+)=(.+)$")
    if not script_name then script_name = name real_name = name end
    local content
    if not compile then
        local f = assert(io.open(real_name, "rb"))
        content = assert(f:read "*a")
        f:close()
    else
        local chunk = assert(loadfile(real_name))
        content = string.dump(chunk)
    end
    glue = glue .. struct.pack("I4I4I4ss", LUA_BLOCK, #script_name+1, #content+1, script_name, content)
end

function do_str(name_value)
    local name, value = string.match(name_value, "^([%w_]+)=(.*)$")
    if not name then
        print("Invalid string")
        os.exit(1)
    end
    if string.sub(value, 1, 1) == "@" then
        local f = assert(io.open(string.sub(value, 2), "rb"))
        value = assert(f:read "*a")
        f:close()
    end
    glue = glue .. struct.pack("I4I4I4sc0", STRING_BLOCK, #name+1, #value, name, value)
end

function do_file(name)
    local filename, realname = string.match(name, "^(.+)=(.+)$")
    if not filename then filename=name realname=name end
    local f = assert(io.open(realname, "rb"))
    local content = assert(f:read "*a")
    f:close()
    glue = glue .. struct.pack("I4I4I4sc0", FILE_BLOCK, #filename+1, #content, filename, content)
end

function do_dir(name)
    glue = glue .. struct.pack("I4I4I4s", DIR_BLOCK, #name+1, 0, name)
end

for i, cmd in ipairs(arg) do
    action, param = string.match(cmd, "^(%w+):(.*)$")
    print(action, param)
    if action == "read" then do_read(param)
    elseif action == "write" then do_write(param)
    elseif action == "lua" then do_lua(param)
    elseif action == "str" then do_str(param)
    elseif action == "file" then do_file(param)
    elseif action == "dir" then do_dir(param)
    else
        print("Unrecognized parameter: "..cmd)
        os.exit(1)
    end
end
