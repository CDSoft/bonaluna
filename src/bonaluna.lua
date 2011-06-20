--[[ BonaLuna test and documentation generator

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
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

function p(fmt, ...)
    io.stderr:write(string.format(fmt, ...).."\n")
end

BONALUNA_VERSION = assert(io.popen(arg[-1].." -v")):read("*l"):gsub("BonaLuna%s([%d%.]+).*", "%1")

doc([[
..  BonaLuna

..  Copyright (C) 2010-2011 Christophe Delord
    http://www.cdsoft.fr/bl/bonaluna.html

..  BonaLuna is based on Lua 5.2
    Copyright (C) 2010 Lua.org, PUC-Rio.

..  Freely available under the terms of the Lua license.

==========
 BonaLuna
==========
-------------------------
 A compact Lua extension
-------------------------

.. sidebar:: Based on `Lua 5.2 <http://www.lua.org/work>`__

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
    | **Lua**: `Lua license <http://www.lua.org/license.html#5>`__
    | **miniLZO**, **QuickLZ**: GPL v2
    | **LZ4**: BSD
    | **libcurl**: `MIT/X derivate <http://curl.haxx.se/docs/copyright.html>`__
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

BonaLuna is based on `]].._VERSION..[[ <lua/contents.html>`__.

BonaLuna packages
=================
]])

doc [[
crypt: Cryptographic functions
-------------------------------

The `crypt` package is a pure Lua package (i.e. not really fast).
]]

doc [[
Functions
~~~~~~~~~

crypt.base64.encode
    | `crypt.base64.encode(data)` encodes `data` in base64.

crypt.base64.decode
    | `crypt.base64.decode(data)` decodes the base64 `data`.

crypt.crc32
    | `crypt.crc32(data)` computes the CRC32 of `data`.

crypt.sha1, crypt.sha224, crypt.sha256
    | `crypt.shaXXX(data)` computes an SHA digest of `data`.

]]

doc [[
Objects
~~~~~~~

crypto.AES
    | `crypto.AES(password [,keylen [,mode] ])` returns an AES codec.
      `password` is the encryption/decryption key, `keylen` is the length
      of the key (128 (default), 192 or 256), `mode` is the encryption/decryption
      mode ("cbc" (default) or "ecb").
      `crypto.AES` objects have two methods: `encrypt(data)` and `decrypt(data)`.

]]

if crypt then
    local data = "The quick brown fox jumps over the lazy dog"
    -- base64
    assert(crypt.base64.encode(data) == "VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZw==")
    assert(crypt.base64.decode("VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZw==") == data)
    -- crc32
    assert(crypt.crc32(data) == 0x414FA339)
    -- sha1
    assert(crypt.sha1(data) == "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12")
    -- sha224, sha256
    assert(crypt.sha224(data) == "730e109bd7a8a32b1cb9d9a09aa2325d2430587ddbc0c38bad911525")
    assert(crypt.sha256(data) == "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592")
    -- aes
    local keylen = {128, 192, 256}
    local method = {"ecb", "cbc"}
    for i = 1, #keylen+1 do
    for j = 1, #method+1 do
    if not (keylen[i] == nil and method[j] ~= nil) then
        local aes = crypt.AES("my key", keylen[i], method[j])
        local aes2 = crypt.AES("your key", keylen[i], method[j])
        assert(aes.encrypt(data) ~= data)
        assert(aes.decrypt(aes.encrypt(data)) == data)
        assert(aes2.encrypt(data) ~= data)
        assert(aes2.decrypt(aes2.encrypt(data)) == data)
        assert(aes2.encrypt(data) ~= aes.encrypt(data))
        assert(not aes2.decrypt(aes.encrypt(data)))
        assert(not aes.decrypt(aes2.encrypt(data)))
    end
    end
    end
end

doc [[
curl: libcurl interface
-----------------------

`libcurl <http://curl.haxx.se/>`__ is multiprotocol file transfer library.
This package is a simple Lua interface to libcurl.

This package is based on `Lua-cURL <http://luaforge.net/projects/lua-curl/>`__
and provides the same API plus a few higher level objects.

Objects
~~~~~~~

curl.FTP
    | `curl.FTP(url [, login, password])` creates an FTP object to connect to
      the FTP server at `url`. `login` and `password` are optional.
      Methods are:

        - `cd(path)`: changes the *current working directory*. No connection is
          made, `path` is just stored internally for later connections.

        - `get(path)`: retrieves `path`.

        - `put(path, data)`: sends and stores the string `data` to the file `path`.

        - `del(path)`: deletes the file `path`.

        - `mkdir(path)`: creates the directory `path`.

        - `rmdir(path)`: deletes the directory `path`.

        - `list(path)`: returns an iterator listing the directory `path`.

FTP connections are made through the cURL easy interface, each request is in
fact an entire connection (and deconnection).
]]

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
        local dirs = {}
        for name in fs.walk(path) do
            if fs.stat(name).type == "directory" then
                table.insert(dirs, name)
            else
                assert(fs.remove(name))
            end
        end
        while #dirs > 0 do
            assert(fs.remove(table.remove(dirs)))
        end
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

fs.walk
    | `fs.walk(path)` returns an iterator listing directory and file names
      in `path` and its subdirectories.
    | `fs.walk()` is equivalent to `fs.walk('.')`.

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
    io.open("foo/bar/file3.lua", "w"):close()
    local function check_foo(dir, path)
        assert(#dir == 3)
        assert(dir[1]~=dir[2] and dir[1]~=dir[3] and dir[2]~=dir[3])
        assert(dir[1]=="file1.c" or dir[1]=="file2.lua" or dir[1]=="bar", dir[1])
        assert(dir[2]=="file1.c" or dir[2]=="file2.lua" or dir[2]=="bar", dir[2])
        assert(dir[3]=="file1.c" or dir[3]=="file2.lua" or dir[3]=="bar", dir[3])
    end
    local foo = assert(fs.dir("foo"))
    check_foo(foo, "foo")
    assert(fs.chdir("foo"))
    foo = assert(fs.dir())
    check_foo(foo, ".")
    assert(fs.chdir(".."))
    local function check_foo2(dir)
        assert(#dir == 2)
        assert(dir[1]~=dir[2])
        assert(dir[1]=="file2.lua" or dir[1]=="bar2", dir[1])
        assert(dir[2]=="file2.lua" or dir[2]=="bar2", dir[2])
    end
    local names = {
        "foo",
            "foo/file1.c",
            "foo/file2.lua",
            "foo/bar",
                "foo/bar/file3.lua"
    }
    local i = 0
    for name in fs.walk "foo" do
        i = i + 1
        assert(name == names[i]:gsub("/", fs.sep))
    end
    assert(fs.remove("foo/file1.c"))
    assert(fs.rename("foo/bar", "foo/bar2"))
    check_foo2(fs.dir("foo"))
    local function check_foo3(dir)
        assert(#dir == 1)
        assert(dir[1]=="file3.lua", dir[1])
    end
    assert(fs.remove("foo/bar2/file3.lua"))
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
        - `mode`: file permissions
        - `uR`, `uW`, `uX`: user Read/Write/eXecute permissions
        - `gR`, `gW`, `gX`: group Read/Write/eXecute permissions
        - `oR`, `oW`, `oX`: other Read/Write/eXecute permissions
        - `dev`, `ino`: device and inode numbers

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
lz: compression library
-----------------------

The lz package uses `miniLZO <http://www.oberhumer.com/opensource/lzo/#minilzo>`__, `QuickLZ <http://www.quicklz.com/>`__ and `LZ4 <http://code.google.com/p/lz4/>`__.
It's inspired by the `Lua Lzo module <http://lua-users.org/wiki/LuaModuleLzo>`__.

Future versions of BonaLuna may remove or add some compression library.

Currently, only QuickLZ is used in the default BonaLuna distribution
but you can change it in `setup`.
]]

doc [[
Functions
~~~~~~~~~

lz.lzo, lz.qlz, lz.lz4, lz.best
    | `lz.lzo()` selects the LZO compression library.
    | `lz.qlz()` selects the QuickLZ compression library.
    | `lz.lz4()` selects the LZ4 compression library.
    | `lz.best()` selects both compression libraries and choose the best.
    | These functions are available only if several compression libraries
      are selected in `setup`.

lz.compress
    | `lz.compress(data)` compresses `data` and returns the compressed string.

lz.decompress
    | `lz.decompress(data)` decompresses `data` and returns the decompressed string.
]]

if lz then
    local a = "This is a test string"
    local b = "And this is another test string"
    local big = string.rep("a lot of bytes; ", 100000)
    local function default() end
    local methods = {default, lz.lzo, lz.qlz, lz.lz4, lz.best}
    for i = 1, 5 do
        if methods[i] then
            methods[i]()
            assert(lz.decompress(lz.compress(a)) == a)
            assert(lz.decompress(lz.compress(b)) == b)
            assert(lz.decompress(lz.compress(big)) == big)
            assert(#lz.compress(big) < #big)
            local ok, err = lz.decompress("not a compressed string")
            assert(ok == nil and err == "lz: not a compressed string")
        end
    end
    if lz.best then lz.best() end
end

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

`pegar.lua` parameters
----------------------

`compile:on|off|min`
    turn compilation on, off or on when chunks are smaller than sources
    (`min` is the default value)

`compress:on|off|min`
    turn compression on, off or on when chunks are smaller than sources
    (`min` is the default value)

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
            os.execute(stub.." ../tools/pegar.lua -q"..
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
