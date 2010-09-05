--[[ BonaLuna test and documentation generator

Copyright (C) 2010 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 work 4
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

do
    local bluna_rst = "bonaluna.rst"
    function doc(txt)
        local f = assert(io.open(bluna_rst, "a"))
        f:write(txt)
        f:write("\n")
        f:close()
    end
    os.remove(bluna_rst)
end

BONALUNA_VERSION = assert(io.popen(arg[-1].." -v")):read("*l"):gsub("BonaLuna%s([%d%.]+).*", "%1")

doc([[
..  BonaLuna

..  Copyright (C) 2010 Christophe Delord
    http://www.cdsoft.fr/bl/bonaluna.html

..  BonaLuna is based on Lua 5.2 work 4
    Copyright (C) 2010 Lua.org, PUC-Rio.

..  Freely available under the terms of the Lua license.

==========
 BonaLuna
==========
-------------------------
 A compact Lua extension
-------------------------

.. sidebar:: Based on `Lua 5.2 work 4 <http://www.lua.org/work>`__

    .. image:: http://www.andreas-rozek.de/Lua/Lua-Logo_64x64.png

    Copyright (C) 2010 `Lua.org <http://www.lua.org>`__, PUC-Rio.

:Author: Christophe Delord
:Contact: cdelord@cdsoft.fr
:Web: http://cdsoft.fr/bl/bonaluna.html
:License:
    | Copyright (C) 2010 Christophe Delord,
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

BonaLuna is based on ]].._VERSION..[[ work 4.

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

do
    os.execute("rm -rf foo")
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
    os.execute("rm -rf foo")
end

doc [[
fs.dir
    | `fs.dir(path)` returns the list of files and directories in
      `path`.
    | `fs.dir()` returns the list of files and directories in the
      current directory.

fs.mkdir
    | `fs.mkdir(path) creates a new directory `path`.

fs.rename
    | `fs.rename(old_name, new_name)` renames the file `old_name` to
      `new_name`.

fs.remove
    | `fs.remove(name)` deletes the file `name`.
]]

do
    os.execute("rm -rf foo")
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
    os.execute("rm -rf foo")
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
    os.execute("rm -rf foo")
    fs.mkdir("foo")
    check("foo", { name="foo", type="directory",
                   mtime=os.time(), atime=os.time(), ctime=os.time(),
                   uR=true, uW=true, uX=true,
                   gR=true, gW=false, gX=true,
                   oR=true, oW=false, oX=true,
    })
    os.execute("rm -rf foo")
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
sys: System management
----------------------
]]

doc [[
Functions
~~~~~~~~~
]]

doc [[
sys.hostname:
    | `sys.hostname()` returns the host name.

sys.domainname:
    | `sys.domainname()` returns the domain name.

sys.hostid:
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
Examples
========

This documentation has been generated by a BonaLuna script.
`bonaluna.lua <bonaluna.lua>`__ also contains some tests.
]]

print "BonaLuna tests passed"
