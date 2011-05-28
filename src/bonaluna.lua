--[[ BonaLuna test and documentation generator

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 alpha
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

do
    local bl_rst = "../doc/bonaluna.rst"
    function doc(txt)
        local f = assert(io.open(bl_rst, "a"))
        f:write(txt)
        f:write("\n")
        f:close()
    end
    os.remove(bl_rst)
end

BONALUNA_VERSION = assert(io.popen(arg[-1].." -v")):read("*l"):gsub("BonaLuna%s([%d%.]+).*", "%1")

doc([[
..  BonaLuna

..  Copyright (C) 2010-2011 Christophe Delord
    http://www.cdsoft.fr/bl/bonaluna.html

..  BonaLuna is based on Lua 5.2 alpha
    Copyright (C) 2010 Lua.org, PUC-Rio.

..  Freely available under the terms of the Lua license.

==========
 BonaLuna
==========
-------------------------
 A compact Lua extension
-------------------------

.. sidebar:: Based on `Lua 5.2 alpha <http://www.lua.org/work>`__

    .. image:: http://www.andreas-rozek.de/Lua/Lua-Logo_64x64.png

    Copyright (C) 2010 `Lua.org <http://www.lua.org>`__, PUC-Rio.

:Author: Christophe Delord
:Contact: cdelord@cdsoft.fr
:Web: http://cdsoft.fr/bl/bonaluna.html
:License:
    | Copyright (C) 2010-2011 Christophe Delord,
      `CDSoft.fr <http://cdsoft.fr/bl/bonaluna.html>`__
    | Freely available under the terms of the
      `Lua license <http://www.lua.org/license.html#5>`__
:Download: http://cdsoft.fr/bl/bonaluna-]]..BONALUNA_VERSION..[[.tgz

:Version: ]]..BONALUNA_VERSION..[[

:Abstract:
    BonaLuna is a Lua interpretor plus a few packages
    in a single executable.

.. contents:: Table of Contents
    :depth: 2

.. sectnum::
    :depth: 2
]])

doc([[
Lua
===

The original Lua interpretor and documentation is available
at http://www.lua.org.

BonaLuna is based on `]].._VERSION..[[ alpha <lua/contents.html>`__.

BonaLuna packages
=================
]])

doc [[
fs: File System
---------------
]]

doc [[
Functions
~~~~~~~~~
]]

doc [[
fs.getcwd
    | `fs.getcwd()` returns the current working directory.

fs.chdir
    | `fs.chdir(path)` changes the current directory to `path`.
]]

function rm_rf(path)
    if fs.stat(path) then
        local files = fs.dir(path)
        if files then
            for i = 1, #files do
                assert(fs.remove(path..fs.sep..files[i].name))
            end
        end
        assert(fs.remove(path))
    end
end

do
    rm_rf "foo"
    local old_path = assert(fs.getcwd())
    assert(fs.mkdir("foo"))
    assert(fs.chdir("foo"))
    local new_path = assert(fs.getcwd())
    assert(fs.chdir('..'))
    assert(fs.getcwd() == old_path)
    assert(fs.chdir("foo"))
    assert(fs.getcwd() == new_path)
    assert(fs.chdir(old_path))
    assert(fs.getcwd() == old_path)
    rm_rf "foo"
end

doc [[
fs.dir
    | `fs.dir(path)` returns the list of files and directories in
      `path`.
    | `fs.dir()` returns the list of files and directories in the
      current directory.

fs.mkdir
    | `fs.mkdir(path)` creates a new directory `path`.

fs.rename
    | `fs.rename(old_name, new_name)` renames the file `old_name` to
      `new_name`.

fs.remove
    | `fs.remove(name)` deletes the file `name`.
]]

do
    rm_rf "foo"
    assert(fs.mkdir("foo"))
    io.open("foo/file1.c", "w"):close()
    assert(fs.mkdir("foo/bar"))
    io.open("foo/file2.lua", "w"):close()
    local function check_foo(dir, path)
        assert(#dir == 3)
        assert(dir[1].name~=dir[2].name and dir[1].name~=dir[3].name and dir[2].name~=dir[3].name)
        assert(dir[1].name=="file1.c" or dir[1].name=="file2.lua" or dir[1].name=="bar", dir[1].name)
        assert(dir[2].name=="file1.c" or dir[2].name=="file2.lua" or dir[2].name=="bar", dir[2].name)
        assert(dir[3].name=="file1.c" or dir[3].name=="file2.lua" or dir[3].name=="bar", dir[3].name)
        assert(dir[1].type==(dir[1].name=="bar" and "directory" or "file"))
        assert(dir[2].type==(dir[2].name=="bar" and "directory" or "file"))
        assert(dir[3].type==(dir[3].name=="bar" and "directory" or "file"))
        assert(dir[1].path == path..fs.sep..dir[1].name)
    end
    local foo = assert(fs.dir("foo"))
    check_foo(foo, "foo")
    assert(fs.chdir("foo"))
    foo = assert(fs.dir())
    check_foo(foo, ".")
    assert(fs.chdir(".."))
    local function check_foo2(dir)
        assert(#dir == 2)
        assert(dir[1].name~=dir[2].name)
        assert(dir[1].name=="file2.lua" or dir[1].name=="bar2", dir[1].name)
        assert(dir[2].name=="file2.lua" or dir[2].name=="bar2", dir[2].name)
        assert(dir[1].type==(dir[1].name=="bar2" and "directory" or "file"))
        assert(dir[2].type==(dir[2].name=="bar2" and "directory" or "file"))
    end
    assert(fs.remove("foo/file1.c"))
    assert(fs.rename("foo/bar", "foo/bar2"))
    check_foo2(fs.dir("foo"))
    local function check_foo3(dir)
        assert(#dir == 1)
        assert(dir[1].name=="file3.lua", dir[1].name)
        assert(dir[1].type=="file")
    end
    assert(fs.remove("foo/bar2"))
    assert(fs.rename("foo/file2.lua", "foo/file3.lua"))
    check_foo3(fs.dir("foo"))
    assert(fs.remove("foo/file3.lua"))
    assert(#fs.dir("foo")==0)
    rm_rf "foo"
end

doc [[
fs.copy
    | `fs.copy(source_name, target_name)` copies file
      `source_name` to `target_name`. The attributes and
      times are preserved.
]]

do
    local content = string.rep(
        "I don't remember the question, but for sure, the answer is 42!\n",
        42*1000)
    local f = assert(io.open("answer", "wb"))
    f:write(content)
    f:close()
    assert(fs.touch("answer", 42))
    assert(fs.chmod("answer", fs.aR))
    assert(fs.copy("answer", "answer-2"))
    f = assert(io.open("answer-2", "rb"))
    assert(f:read("*a") == content)
    f:close()
    assert(fs.stat("answer-2").mode == fs.stat("answer").mode)
    assert(fs.stat("answer-2").mtime == 42)
    if sys.platform == "Windows" then
        assert(fs.chmod("answer", fs.aR, fs.aW))
        assert(fs.chmod("answer-2", fs.aR, fs.aW))
    end
    fs.remove("answer")
    fs.remove("answer-2")
end

doc [[
fs.stat
    | `fs.stat(name)` reads attributes of the file `name`.
      Attributes are:

        - `name`: name
        - type: "file" or "directory"
        - `size`: size in bytes
        - `mtime`, `atime`, `ctime`: modification, access and creation
          times.
        - mode: file permissions
        - uR, uW, uX: user Read/Write/eXecute permissions
        - gR, gW, gX: group Read/Write/eXecute permissions
        - oR, oW, oX: other Read/Write/eXecute permissions
]]

do
    local function check(name, attrs)
        local st = fs.stat(name)
        assert(st.name == attrs.name)
        if (st.type=="file") then assert(st.size == attrs.size) end
        assert(math.abs(st.mtime-attrs.mtime)<=1)
        assert(math.abs(st.atime-attrs.atime)<=1)
        assert(math.abs(st.ctime-attrs.ctime)<=1)
        assert(st.uR == attrs.uR)
        assert(st.uW == attrs.uW)
        assert(st.uX == attrs.uX)
        if sys.platform == 'Linux' then
            assert(st.gR == attrs.gR)
            assert(st.gW == attrs.gW)
            assert(st.gX == attrs.gX)
            assert(st.oR == attrs.oR)
            assert(st.oW == attrs.oW)
            assert(st.oX == attrs.oX)
        end
    end
    rm_rf "foo"
    fs.mkdir("foo")
    check("foo", { name="foo", type="directory",
                   mtime=os.time(), atime=os.time(), ctime=os.time(),
                   uR=true, uW=true, uX=true,
                   gR=true, gW=false, gX=true,
                   oR=true, oW=false, oX=true,
    })
    rm_rf "foo"
end

doc [[
fs.chmod
    | `fs.chmod(name, other_file_name)` sets file `name` permissions as
      file `other_file_name` (string containing the name of another
      file).
    | `fs.chmod(name, bit1, ..., bitn) sets file `name` permissions as
      `bit1` or ... or `bitn` (integers).
]]

do
    local function check(name, mode, uR, uW, uX, gR, gW, gX, oR, oW, oX)
        if sys.platform == 'Windows' then
            uR = true
            uX = false
        end
        if type(mode) == 'string' then
            assert(fs.chmod(name, mode))
        else
            assert(fs.chmod(name, table.unpack(mode)))
        end
        local st = fs.stat(name)
        assert(st.uR == uR)
        assert(st.uW == uW)
        assert(st.uX == uX)
    end
    fs.chmod("bar", fs.aR, fs.aW); fs.remove("bar")
    fs.remove("bar2")
    assert(io.open("bar", "w")):close()
    assert(io.open("bar2", "w")):close()
    check("bar", {fs.uX, fs.gW, fs.oR},
        false, false, true,
        false, true, false,
        true, false, false)
    check("bar2", {fs.aR, fs.aW, fs.aX},
        true, true, true,
        true, true, true,
        true, true, true)
    check("bar", "bar2",
        true, true, true,
        true, true, true,
        true, true, true)
    fs.remove("bar")
    fs.remove("bar2")
end

doc [[
fs.touch
    | `fs.touch(name)` sets the access time and the modification time
      of file `name` with the current time.
    | `fs.touch(name, number)` sets the access time and the
      modification time of file `name` with `number`.
    | `fs.touch(name, other_name)` sets the access time and the
      modification time of file `name` with the times of file
      `other_name`.
]]

do
    local function check(name, mtime, atime)
        local st = fs.stat(name)
        assert(math.abs(st.mtime-mtime)<=1)
        assert(math.abs(st.atime-atime)<=1)
    end
    local t0 = os.time()
    io.open("bar", "w"):close()
    io.open("bar2", "w"):close()
    assert(fs.touch("bar", 42))
    check("bar", 42, 42)
    assert(fs.touch("bar", "bar2"))
    check("bar", t0, t0)
    assert(fs.touch("bar", 42))
    check("bar", 42, 42)
    local t1 = os.time()
    assert(fs.touch("bar"))
    check("bar", t1, t1)
    fs.remove("bar")
    fs.remove("bar2")
end

doc [[
fs.basename
    `fs.basename(path)` return the last component of path.

fs.dirname
    `fs.dirname(path)` return all but the last component of path.

fs.absname
    `fs.absname(path)` return the absolute path name of path.
]]

do
    assert(fs.basename("/usr/bin/bash") == "bash")
    assert(fs.basename("/usr/bin/") == "bin")
    assert(fs.basename("C:\\bin\\bl.exe") == "bl.exe")
    assert(fs.basename("bl") == "bl")
    assert(fs.basename("/") == "")
    assert(fs.dirname("/usr/bin/bash") == "/usr/bin")
    assert(fs.dirname("/usr/bin/") == "/usr")
    assert(fs.dirname("C:\\bin\\bl.exe") == "C:\\bin")
    assert(fs.dirname("bl") == "")
    assert(fs.dirname("/") == "")
    assert(fs.absname("/usr/bin/bash") == "/usr/bin/bash")
    assert(fs.absname("C:\\foo.txt") == "C:\\foo.txt")
    assert(fs.absname("foo/bar") == fs.getcwd()..fs.sep.."foo/bar")
end

doc [[
Constants
~~~~~~~~~

fs.sep
    Directory separator (/ or \\)

fs.uR, fs.uW, fs.uX
    User Read/Write/eXecute mask for `fs.chmod`

fs.gR, fs.gW, fs.gX
    Group Read/Write/eXecute mask for `fs.chmod`

fs.oR, fs.oW, fs.oX
    Other Read/Write/eXecute mask for `fs.chmod`

fs.aR, fs.aW, fs.aX
    All Read/Write/eXecute mask for `fs.chmod`
]]

doc [[
lzo: compression library
------------------------

The lzo package uses `miniLZO <http://www.oberhumer.com/opensource/lzo/#minilzo>`__
and is inspired by the `Lua Lzo module <http://lua-users.org/wiki/LuaModuleLzo>`__.
]]

doc [[
Functions
~~~~~~~~~

lzo.adler
    | `lzo.adler(adler, buf)` computes the Adler-32 checksum of `buf`
       using `adler` as initial value.
    | `lzo.adler(buf)` computes the Adler-32 checksum of `buf`
       using `0` as initial value.

lzo.compress
    | `lzo.compress(data)` compresses `data` and returns the compressed string.

lzo.decompress
    | `lzo.decompress(data)` decompresses `data` and returns the decompressed string.
]]

do
    local a = "This is a test string"
    local b = "And this is another test string"
    local big = string.rep("a lot of bytes; ", 10000)
    assert(lzo.adler(a) == 1362364332)
    assert(lzo.adler(b) == 2993425295)
    assert(lzo.adler(a..b) == 4051899195)
    assert(lzo.adler(a) == lzo.adler(0, a))
    assert(lzo.adler(a..b) == lzo.adler(lzo.adler(a), b))
    assert(lzo.decompress(lzo.compress(a)) == a)
    assert(lzo.decompress(lzo.compress(b)) == b)
    assert(lzo.decompress(lzo.compress(big)) == big)
    assert(#lzo.compress(big)/#big < 0.01)
    assert(#lzo.compress("") == 11) -- same header size on all platforms
    local ok, err = lzo.decompress("not an LZO string")
    assert(ok == nil and err == "lzo error - not a compressed string")
end

doc [[
Constants
~~~~~~~~~

lzo.copyright
    miniLZO copyright string

lzo.version
    miniLZO version number

lzo.version_string
    miniLZO version string

lzo.version_date
    miniLZO version date
]]

doc [[
ps: Processes
-------------
]]

doc [[
Functions
~~~~~~~~~
]]

doc [[
ps.sleep
    | `ps.sleep(n)` sleeps for `n` seconds.
]]

do
    local function check(nsec, niter)
        local t0 = os.time()
        for i = 1, niter do ps.sleep(nsec) end
        local t1 = os.time()
        assert(math.abs((t1-t0)/niter / nsec - 1.0) <= 1e-3)
    end
    --check(2, 1)
    --check(0.1, 50)
    --check(0.01, 500)
end

doc [[
rl: readline
------------

The rl (readline) package is taken from
`ilua <https://github.com/ilua>`_
and adapted for BonaLuna.
]]

doc [[
Functions
~~~~~~~~~

rl.read
    | `rl.read(prompt)` prints `prompt` and returns the string entered by the user.

rl.add
    | `rl.add(line)` adds `line` to the readline history.

]]

doc [[
struct: (un)pack structures
---------------------------

The struct package is taken from
`Library for Converting Data to and from C Structs for Lua 5.1 <http://www.inf.puc-rio.br/~roberto/struct/>`_
and adapted for BonaLuna.
]]

doc [[
Functions
~~~~~~~~~
]]

doc [[
struct.pack
    | `struct.pack(fmt, d1, d2, ...)` returns a string containing the values `d1`, `d2`, etc. packed according to the format string `fmt`.

struct.unpack
    | `struct.unpack(fmt, s, [i])` returns the values packed in string `s` according to the format string `fmt`. An optional `i` marks where in `s` to start reading (default is 1). After the read values, this function also returns the index in `s` where it stopped reading, which is also where you should start to read the rest of the string.

struct.size
    | `struct.size(fmt)` returns the size of a string formatted according to the format string `fmt`. For obvious reasons, the format string cannot contain neither the option `s` nor the option `c0`.
]]

do
    assert(struct.unpack("f", struct.pack("f", 1.0)) == 1.0)
    assert(struct.unpack("I4", struct.pack("f", 1.0)) == 0x3F800000)
end

doc [[
sys: System management
----------------------
]]

doc [[
Functions
~~~~~~~~~
]]

doc [[
sys.hostname
    | `sys.hostname()` returns the host name.

sys.domainname
    | `sys.domainname()` returns the domain name.

sys.hostid
    | `sys.hostid()` returns the host id.
]]

do
    if platform == 'Linux' then
        assert(sys.hostname() == io.popen("hostname"):read("*l"))
        assert(sys.domainname() == io.popen("domainname"):read("*l"))
        assert(sys.hostid() == tonumber(io.popen("hostid"):read("*l"), 16))
    end
end

doc [[
Constants
~~~~~~~~~

sys.platform
    `"Linux"` or `"Windows"`
]]

doc [[
Self running scripts
====================

It is possible to add scripts to the BonaLuna interpretor
to make a single executable file containing the interpretor
and some BonaLuna scripts.

This feature is inspired by
`srlua <http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#srlua>`__.

`glue.lua` parameters
---------------------

`compile:on`
    turn compilation on

`compile:off`
    turn compilation off

`compile:min`
    turn compilation on when chunks are smaller than sources
    (this is the default value)

`compress:on`
    turn compression on

`compress:off`
    turn compression off

`compress:min`
    turn compression on when chunks are smaller than sources
    (this is the default value)

`read:original_interpretor`
    reads the initial interpretor

`lua:script.lua`
    adds a script to be executed at runtime

`lua:script.lua=realname.lua`
    as above but stored under a different name

`str:name=value`
    creates a global variable holding a string

`str:name=@filename`
    as above but the string is the content of a file

`file:name`
    adds a file to be created at runtime
    (the file is not overwritten if it already exists)

`file:name=realname`
    as above but stored under a different name

`dir:name`
    creates a directory at runtime

`write:new_executable`
    write a new executable containing the original interpretor
    and all the added items

When a path starts with `:`, it is relative to the executable path otherwise
it is relative to the current working directory.

]]

do
    local stub = arg[-1]
    local compress, compile
    local big_file = string.rep("what a big file", 10000)
    local big_str = string.rep("what a big string", 10000)
    for _, compress in ipairs{'on', 'off', 'min'} do
        for _, compile in ipairs{'on', 'off', 'min'} do

            rm_rf "tmp"
            assert(fs.mkdir "tmp")
            local f = io.open("tmp/hello.lua", "w")
            f:write [[#! the shebang that loadstring doesn't like
                assert(fs.basename(arg[-1]) == "hello.exe")
                assert(arg[0] == "hello.lua")
                assert(arg[1] == "a")
                assert(arg[2] == "b")
                assert(arg[3] == "c")
                assert(big_str == string.rep("what a big string", 10000))
                print(my_constant*14)
            ]]
            f:write("\n--"..string.rep("a big compressible and useless comment...", 10000).."\n")
            f:write("z = [["..string.rep("a big compressible and useless string...", 10000).."]]\n")
            f:close()
            f = io.open("tmp/exit.lua", "w")
            f:write [[ os.exit() ]]
            f:close()
            f = io.open("tmp/hello.flag", "w")
            f:write [[ hi ]]
            f:close()
            f = io.open("tmp/hello.big_file", "w")
            f:write(big_file)
            f:close()
            f = io.open("tmp/hello.big_str", "w")
            f:write(big_str)
            f:close()
            os.execute(stub.." ../tools/glue.lua -q"..
                " compile:"..compile..
                " compress:"..compress..
                " read:"..stub..
                " file::/hello.flag2=tmp/hello.flag"..
                " file::/hello.big_file2=tmp/hello.big_file"..
                " str:big_str=@tmp/hello.big_str"..
                " dir:tmp/hello.dir"..
                " str:my_constant=3"..
                " lua:hello.lua=tmp/hello.lua"..
                " lua:exit.lua=tmp/exit.lua"..
                " write:tmp/hello.exe")
            assert(fs.stat("tmp/hello.exe"))
            assert(tonumber(io.popen("tmp"..fs.sep.."hello.exe a b c"):read("*a")) == 42)
            f = io.open("tmp/hello.flag2", "rb")
            assert(f:read("*a") == [[ hi ]])
            f:close()
            f = io.open("tmp/hello.big_file", "rb")
            assert(f:read("*a") == big_file)
            f:close()
            assert(fs.stat("tmp/hello.dir").type == "directory")

        end
    end
    rm_rf "tmp"
end

doc [[
Examples
========

This documentation has been generated by a BonaLuna script.
`bonaluna.lua <bonaluna.lua>`__ also contains some tests.
]]

print "BonaLuna tests passed"
