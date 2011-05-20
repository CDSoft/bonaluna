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
:Download: http://cdsoft.fr/bl/bonaluna-1.0.0.tgz

:Version: 1.0.0
:Abstract:
    BonaLuna is a Lua interpretor plus a few packages
    in a single executable.

.. contents:: Table of Contents
    :depth: 2

.. sectnum::
    :depth: 2

Lua
===

The original Lua interpretor and documentation is available
at http://www.lua.org.

BonaLuna is based on `Lua 5.2 alpha <lua/contents.html>`__.

BonaLuna packages
=================

fs: File System
---------------

Functions
~~~~~~~~~

fs.getcwd
    | `fs.getcwd()` returns the current working directory.

fs.chdir
    | `fs.chdir(path)` changes the current directory to `path`.

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

fs.copy
    | `fs.copy(source_name, target_name)` copies file
      `source_name` to `target_name`. The attributes and
      times are preserved.

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

fs.chmod
    | `fs.chmod(name, other_file_name)` sets file `name` permissions as
      file `other_file_name` (string containing the name of another
      file).
    | `fs.chmod(name, bit1, ..., bitn) sets file `name` permissions as
      `bit1` or ... or `bitn` (integers).

fs.touch
    | `fs.touch(name)` sets the access time and the modification time
      of file `name` with the current time.
    | `fs.touch(name, number)` sets the access time and the
      modification time of file `name` with `number`.
    | `fs.touch(name, other_name)` sets the access time and the
      modification time of file `name` with the times of file
      `other_name`.

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

ps: Processes
-------------

Functions
~~~~~~~~~

ps.sleep
    | `ps.sleep(n)` sleeps for `n` seconds.

rl: readline
------------

The rl (readline) package is taken from
`ilua <https://github.com/ilua>`_
and adapted for BonaLuna.

Functions
~~~~~~~~~

rl.read
    | `rl.read(prompt)` prints `prompt` and returns the string entered by the user.

rl.add
    | `rl.add(line)` adds `line` to the readline history.


struct: (un)pack structures
---------------------------

The struct package is taken from
`Library for Converting Data to and from C Structs for Lua 5.1 <http://www.inf.puc-rio.br/~roberto/struct/>`_
and adapted for BonaLuna.

Functions
~~~~~~~~~

struct.pack
    | `struct.pack(fmt, d1, d2, ...)` returns a string containing the values `d1`, `d2`, etc. packed according to the format string `fmt`.

struct.unpack
    | `struct.unpack(fmt, s, [i])` returns the values packed in string `s` according to the format string `fmt`. An optional `i` marks where in `s` to start reading (default is 1). After the read values, this function also returns the index in `s` where it stopped reading, which is also where you should start to read the rest of the string.

struct.size
    | `struct.size(fmt)` returns the size of a string formatted according to the format string `fmt`. For obvious reasons, the format string cannot contain neither the option `s` nor the option `c0`.

sys: System management
----------------------

Functions
~~~~~~~~~

sys.hostname
    | `sys.hostname()` returns the host name.

sys.domainname
    | `sys.domainname()` returns the domain name.

sys.hostid
    | `sys.hostid()` returns the host id.

Constants
~~~~~~~~~

sys.platform
    `"Linux"` or `"Windows"`

Self running scripts
====================

It is possible to add scripts to the BonaLuna interpretor
to make a single executable file containing the interpretor
and some BonaLuna scripts.

This feature is inspired by `srlua`.

`glue.lua` parameters
---------------------

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
    adds a file to be created at runtime (the file is not overwritten if it already exists)

`file:name=realname`
    as above but stored under a different name

`dir:name`
    creates a directory at runtime

`write:new_executable`
    write a new executable containing the original interpretor and all the added items


Examples
========

This documentation has been generated by a BonaLuna script.
`bonaluna.lua <bonaluna.lua>`__ also contains some tests.

