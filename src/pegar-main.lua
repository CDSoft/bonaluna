
local usage = [[
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
