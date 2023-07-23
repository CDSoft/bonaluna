BonaLuna - A compact Lua extension
==================================

[BonaLuna](http://cdelord.fr/bl/bonaluna.html) is a Lua interpretor plus a few packages in a single executable.

The current version is 3.0.7

Licenses
--------

* **[BonaLuna](http://cdelord.fr/bl/bonaluna.html)**: Copyright (C) 2010-2020 Christophe Delord, Freely available under the terms of the [MIT license](http://www.lua.org/license.html)
* **[Lua 5.3](http://www.lua.org)**: Copyright (C) 2010 [Lua.org](http://www.lua.org>), PUC-Rio.
* **Lua**, **Lpeg**: [MIT license](http://www.lua.org/license.html)
* **miniLZO**, **QuickLZ**: GPL v2
* **LZ4**: BSD
* **LZF**: GPL
* **libcurl**: [MIT/X derivate](http://curl.haxx.se/docs/copyright.html)
* **ser**: MIT license

Download
--------

Bonaluna sources can be downloaded here: <https://github.com/CDSoft/bonaluna>.

Lua
===

The original Lua interpretor and documentation is available
at http://www.lua.org.

BonaLuna is based on [Lua 5.3](lua/contents.html).

Global functions
================

Iterators
---------

**iter(sequence)** returns an iterator of `sequence` items (a table).

**list(iterator)** returns a table of items generated by `iterator`.

**reverse(iterator)** returns `iterator` in reverse order.

**sort(iterator [, cmp])** returns `iterator` sorted using `cmp` (as `table.sort`)

**map(f, ...)** applies `f` to iterators.

**zip(...)** groups values of the same rank of several iterators.

**filter(p, iterator)** selects values according to the predicate `p`.

**range(i [, j [, s] ])** returns the values of the range [`i`, `j`].
`s` is the step.
`range(j)` is equivalent to `range(1, j)`. The default step is 1.

**enum(iterator)** generates tuples `(i, x[i])` where `i` is the rank of the value `x[i]` for each value of `iterator`.

**chain(...)** chains several iterators.

Higher order functions
----------------------

**curry(f, ...)** returns a curryfied function starting with f and its first arguments (...) if any.

**compose(f, g, ...)** returns the composed function "f(g(...))".

**identity** is the identity function.

**memoize(f)** returns a memoized function.

BonaLuna packages
=================

Note about objects
------------------

Objects defined in these packages uses closures [^1] to store internal data.
No *self* is required and methods are called with a single dot (`.`),
not with a colon (`:`).

Example:

    aes = crypt.AES("my key", 128)
    encrypted = aes.encrypt("some text")

[^1]: See [Object Orientation Closure Approach](http://lua-users.org/wiki/ObjectOrientationClosureApproach).

bc, m: arbitrary precision library for Lua based on GNU bc
----------------------------------------------------------

lbc is a public domain package written by Luiz Henrique de Figueiredo and available at
[Libraries and tools for Lua](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lbc)

This is a big-number library for Lua 5.3. It is based on the arbitrary
precision library number.c written by Philip A. Nelson for GNU bc-1.06:
http://www.gnu.org/software/bc/

### basic bc functions

**bc.version** is the version number of bc

**bc.digits([n])** sets the number of digits used by bc

**bc.number(x)** builds a big number from a Lua number or a string

**bc.tonumber(x)** converts a big number to a Lua number

**bc.tostring(x), \_\_tostring(x)** converts a big number to a string

**bc.neg(x), \_\_unm(x)** returns `-x`

**bc.add(x,y), \_\_add(x,y)** returns `x+y`

**bc.sub(x,y), \_\_sub(x,y)** returns `x-y`

**bc.mul(x,y), \_\_mul(x,y)** returns `x*y`

**bc.div(x,y), \_\_div(x,y)** returns `x/y`

**bc.mod(x,y), \_\_mod(x,y)** return `x mod y`

**bc.divmod(x,y)** returns `[x/y], x mod y`

**bc.pow(x,y), \_\_pow(x,y)** returns `x**y`

**bc.powmod(x,y,m)** returns `x**y mod m`

**bc.compare(x,y)** returns `-1` if x < y, `0` if x == y, `+1` if x > y

**\_\_eq(x,y), \_\_lt(x,y)** compares x and y

**bc.iszero(x)** is true if x == 0

**bc.isneg(x)** is true if x < 0

**bc.trunc(x,[n])** returns x truncated value

**bc.sqrt(x)** returns `sqrt(x)`

### Functions added by BonaLuna

**bc.number(x)** also accepts hexadecimal, octal and binary numbers as strings

### Math and bitwise operators

Functions of the math and bit32 modules also exist in the bc module.
These functions produce bc numbers but work internally with Lua numbers.
Do not expect these functions to be precise.

### m package

The m package extends the bc package by mixing arbitrary precision integer (bc)
and Lua numbers (float). It produces bc integers when possible and Lua numbers
otherwise.


bn: arbitrary precision library for Lua written in pure Lua
-----------------------------------------------------------

### basic bn functions

**bn.Int(x)** builds a big integer from a Lua number, a string or a big number

**bn.Rat(x)** builds a big rational from a Lua number, a string or a big number

**bn.Float(x)** builds a float from a Lua number, a string or a big number

**bn.tonumber(x)** converts a big number to a Lua number

**bn.tostring(x, base, bits), \_\_tostring(x)** converts a big number to a string

**\_\_unm(x)** returns `-x`

**\_\_add(x,y)** returns `x+y`

**\_\_sub(x,y)** returns `x-y`

**\_\_mul(x,y)** returns `x*y`

**\_\_div(x,y)** returns `x/y`

**\_\_idiv(x,y)** return `x // y`

**\_\_mod(x,y)** return `x mod y`

**bn.divmod(x,y)** returns `[x/y], x mod y`

**bn.powmod(x,y,m)** returns `x**y mod m`

**\_\_pow(x,y)** returns `x**y`

**\_\_eq(x,y), \_\_lt(x,y)** compares x and y

**x:iszero()** is true if x == 0

**x:isone()** is true if x == 1

**bn.zero, bn.one, bn.two** big representations of `0`, `1` and `2`

**bn.bin(x, bits)** returns a string representation of `x` in base 2 on `bits` bits

**bn.oct(x, bits)** returns a string representation of `x` in base 8 on `bits` bits

**bn.dec(x, bits)** returns a string representation of `x` in base 10 on `bits` bits

**bn.hex(x, bits)** returns a string representation of `x` in base 16 on `bits` bits

**bn.sep(s)** sets the digit separator ("_", " " or nil)

### Math and bitwise operators

Functions of the math, mathx and bit32 modules also exist in the bn module.
These functions produce bn numbers but may work internally with Lua numbers.
Do not expect these functions to be precise.

All the functions of mathx are in the math module.


crypt: Cryptographic functions
------------------------------

The `crypt` package is a pure Lua package (i.e. not really fast).

**crypt.hex.encode(data)** encodes `data` in hexa.

**crypt.hex.decode(data)** decodes the hexa `data`.

**crypt.base64.encode(data)** encodes `data` in base64.

**crypt.base64.decode(data)** decodes the base64 `data`.

**crypt.crc32(data)** computes the CRC32 of `data`.

**crypt.shaXXX(data)** computes an SHA digest of `data`. `XXX` is 1, 224 or 256.

**crypt.AES(password [,keylen [,mode] ])** returns an AES codec.
`password` is the encryption/decryption key, `keylen` is the length
of the key (128 (default), 192 or 256), `mode` is the encryption/decryption
mode ("cbc" (default) or "ecb").
`crypt.AES` objects have two methods: `encrypt(data)` and `decrypt(data)`.

**crypt.BTEA(password)** returns a BTEA codec
(a tiny cipher with reasonable security and efficiency,
see http://en.wikipedia.org/wiki/XXTEA).
`password` is the encryption/decryption key (only the first 16 bytes are used).
`crypt.BTEA` objects have two methods: `encrypt(data)` and `decrypt(data)`.
BTEA encrypts 32-bit words so the length of data should be a multiple of 4
(if not, BTEA will add null padding at the end of data).

**crypt.RC4(password, drop)** return a RC4 codec
(a popular stream cypher, see http://en.wikipedia.org/wiki/RC4).
`password` is the encryption/decryption key.
`drop` is the numbre of bytes ignores before encoding (768 by default).
`crypt.RC4` returns the encryption/decryption function.

**crypt.random(bits)** returns a string with `bits` random bits.


curl: libcurl interface
-----------------------

[libcurl](http://curl.haxx.se/) is multiprotocol file transfer library.
This package is a simple Lua interface to libcurl.

This package is based on [Lua-cURL](http://luaforge.net/projects/lua-curl/)
and provides the same API plus a few higher level objects.

This package was introduced before `socket` which is based on `Lua Socket`.
I recommend using `socket` instead of `curl`.

**curl.FTP(url [, login, password])** creates an FTP object to connect to
the FTP server at `url`. `login` and `password` are optional.
Methods are:

- `cd(path)` changes the *current working directory*. No connection is
  made, `path` is just stored internally for later connections.

- `get(path)` retrieves `path`.

- `put(path, data)` sends and stores the string `data` to the file `path`.

- `rm(path)` deletes the file `path`.

- `mkdir(path)` creates the directory `path`.

- `rmdir(path)` deletes the directory `path`.

- `list(path)` returns an iterator listing the directory `path`.

FTP connections are made through the cURL easy interface, each request is in
fact an entire connection (and deconnection).

**curl.HTTP(url)** creates an HTTP object to connect to the HTTP server at `url`.
Methods are:

- `get(path)` retrieves `path`.

- `save(path [, name])` retrieves `path` and saves it to `name`.
  The default value of `name` is the basename of `path`.

fs: File System
---------------

**fs.getcwd()** returns the current working directory.

**fs.chdir(path)** changes the current directory to `path`.

**fs.listdir([path])** returns the list of files and directories in
`path` (the default path is the current directory).

**fs.dir([path])** returns an iterator listing files and directories in
`path` (the default path is the current directory).

**fs.walk([path])** returns an iterator listing directory and file names
in `path` and its subdirectories (the default path is the current directory).

**fs.mkdir(path)** creates a new directory `path`.

**fs.rename(old_name, new_name)** renames the file `old_name` to `new_name`.

**fs.remove(name)** deletes the file `name`.

**fs.copy(source_name, target_name)** copies file `source_name` to `target_name`.
The attributes and times are preserved.

**fs.stat(name)** reads attributes of the file `name`.  Attributes are:

- `name`: name
- type: "file" or "directory"
- `size`: size in bytes
- `mtime`, `atime`, `ctime`: modification, access and creation times.
- `mode`: file permissions
- `uR`, `uW`, `uX`: user Read/Write/eXecute permissions
- `gR`, `gW`, `gX`: group Read/Write/eXecute permissions
- `oR`, `oW`, `oX`: other Read/Write/eXecute permissions

**fs.inode(name)** reads device and inode attributes of the file `name`.
Attributes are:

- `dev`, `ino`: device and inode numbers


**fs.chmod(name, other_file_name)** sets file `name` permissions as
file `other_file_name` (string containing the name of another file).

**fs.chmod(name, bit1, ..., bitn)** sets file `name` permissions as
`bit1` or ... or `bitn` (integers).

**fs.touch(name)** sets the access time and the modification time of file `name` with the current time.

**fs.touch(name, number)** sets the access time and the modification time of file `name` with `number`.

**fs.touch(name, other_name)** sets the access time and the modification time of file `name` with the times of file `other_name`.

**fs.basename(path)** return the last component of path.

**fs.dirname(path)** return all but the last component of path.

**fs.absname(path)** return the absolute path name of path.


**fs.sep** is the directory separator (/ or \\).

**fs.uR, fs.uW, fs.uX** are the User Read/Write/eXecute mask for `fs.chmod`.

**fs.gR, fs.gW, fs.gX** are the Group Read/Write/eXecute mask for `fs.chmod`.

**fs.oR, fs.oW, fs.oX** are the Other Read/Write/eXecute mask for `fs.chmod`.

**fs.aR, fs.aW, fs.aX** are All Read/Write/eXecute mask for `fs.chmod`.

lpeg, re: parsing library
-------------------------

Bonaluna parsing library is Lpeg.
Both lpeg and re modules are loaded when Bonaluna is started.

The documentation of these modules are available on Lpeg web site:
- [Lpeg](http://www.inf.puc-rio.br/~roberto/lpeg/)
- [Re](http://www.inf.puc-rio.br/~roberto/lpeg/re.html)

z, lzo, qlz, lz4, zlib, ucl, lzma: compression libraries
--------------------------------------------------------

Compression libraries are based on:

- [LZO](http://www.oberhumer.com/opensource/lzo/)
- [QuickLZ](http://www.quicklz.com/)
- [LZ4/LZ4HC](http://code.google.com/p/lz4/)
- [LZF](http://oldhome.schmorp.de/marc/liblzf.html)
- [ZLIB](http://www.zlib.net/)
- [UCL](http://www.oberhumer.com/opensource/ucl/)
- [XZ Utils](http://tukaani.org/xz/)

It's inspired by the [Lua Lzo module](http://lua-users.org/wiki/LuaModuleLzo).

Future versions of BonaLuna may remove or add some compression library.

Currently, only LZ4 is used in the default BonaLuna distribution
but you can change it in `setup`.

**z.compress(data)** compresses `data` using the best compressor and returns the compressed string.

**z.decompress(data)** decompresses `data` and returns the decompressed string.

**minilzo.compress(data)** compresses `data` with miniLZO and returns the compressed string.

**minilzo.decompress(data)** decompresses `data` with miniLZO and returns the decompressed string.

**lzo.compress(data)** compresses `data` with LZO and returns the compressed string.

**lzo.decompress(data)** decompresses `data` with LZO and returns the decompressed string.

**qlz.compress(data)** compresses `data` with QLZ and returns the compressed string.

**qlz.decompress(data)** decompresses `data` with QLZ and returns the decompressed string.

**lz4.compress(data)** compresses `data` with LZ4 and returns the compressed string.

**lz4.decompress(data)** decompresses `data` with LZ4 and returns the decompressed string.

**lz4hc.compress(data)** compresses `data` with LZ4HC and returns the compressed string.

**lz4hc.decompress(data)** decompresses `data` with LZ4HC and returns the decompressed string.

**lzf.compress(data)** compresses `data` with LZF and returns the compressed string.

**lzf.decompress(data)** decompresses `data` with LZF and returns the decompressed string.

**zlib.compress(data)** compresses `data` with ZLIB and returns the compressed string.

**zlib.decompress(data)** decompresses `data` with ZLIB and returns the decompressed string.

**ucl.compress(data)** compresses `data` with UCL and returns the compressed string.

**ucl.decompress(data)** decompresses `data` with UCL and returns the decompressed string.

**lzma.compress(data)** compresses `data` with XZ Utils and returns the compressed string.

**lzma.decompress(data)** decompresses `data` with XZ Utils and returns the decompressed string.

ps: Processes
-------------

**ps.sleep(n)** sleeps for `n` seconds.

rl: readline
------------

The rl (readline) package was initially inspired by
[ilua](https://github.com/ilua)
and adapted for BonaLuna.

**rl.read(prompt)** prints `prompt` and returns the string entered by the user.

**rl.add(line)** adds `line` to the readline history (Linux only).


ser: serialization
------------------

The ser package is written by Robin Wellner (https://github.com/gvx/Ser)
and integrated in BonaLuna in two functions:

**ser.serialize(table)** returns a string that can be evaluated to build
the initial `table`.

**ser.deserialize(src)** evaluates `src` and returns a table.

strings: string module addendum
-------------------------------

BonaLuna adds a few functions to the builtin string module:

**string.split(s, sep, maxsplit, plain)** splits `s` using `sep` as a separator.
If `plain` is true, the separator is considered as plain text.
`maxsplit` is the maximum number of separators to find (ie the remaining string is returned unsplit.
This function returns a list of strings.

**string.gsplit(s, sep, maxsplit, plain)** splits the string as `string.split` but returns an iterator.

**string.lines(s)** splits `s` using '\n' as a separator and returns an iterator.

**string.ltrim(s), string.rtrim(s), string.trim(s)** remove left/right/both end spaces


socket: Lua Socket (and networking tools)
-----------------------------------------

The socket package is based on [Lua Socket](http://w3.impa.br/~diego/software/luasocket/)
and adapted for BonaLuna.

The documentation of `Lua Socket` is available at the [Lua Socket documentation web site](http://w3.impa.br/~diego/software/luasocket/reference.html).

This package also comes with the following functions.

**FTP(url [, login, password])** creates an FTP object to connect to
the FTP server at `url`. `login` and `password` are optional.
Methods are:

- `cd(path)` changes the current working directory.

- `pwd()` returns the current working directory.

- `get(path)` retrieves `path`.

- `put(path, data)` sends and stores the string `data` to the file `path`.

- `rm(path)` deletes the file `path`.

- `mkdir(path)` creates the directory `path`.

- `rmdir(path)` deletes the directory `path`.

- `list(path)` returns an iterator listing the directory `path`.

struct: (un)pack structures
---------------------------

This package was redundant with `string.pack` and `string.unpack` since Lua 5.3.
It has been removed.

One can add `struct = string` to make old scripts compatible.
Some formats are different (`s` becomes `z`, `c0` doesn't exist).

The struct package was taken from
[Library for Converting Data to and from C Structs for Lua 5.1](http://www.inf.puc-rio.br/~roberto/struct/)
and adapted for BonaLuna.

sys: System management
----------------------

**sys.hostname()** returns the host name.

**sys.domainname()** returns the domain name.

**sys.hostid()** returns the host id.

**sys.platform** is `"Linux"` or `"Windows"`

Self running scripts
====================

It is possible to add scripts to the BonaLuna interpretor
to make a single executable file containing the interpretor
and some BonaLuna scripts.

This feature is inspired by
[srlua](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#srlua).

`pegar.lua` parameters (command line interface)
-----------------------------------------------

**compile:on|off|min** turns compilation on, off or on when chunks are smaller than sources (`min` is the default value)

**compress:on|off|min** turns compression on, off or on when chunks are smaller than sources (`min` is the default value)

**read:original_interpretor** reads the initial interpretor

**lua:script.lua** adds a script to be executed at runtime

**lua:script.lua=realname.lua** as above but stored under a different name

**str:name=value** creates a global variable holding a string

**str:name=@filename** as above but the string is the content of a file

**file:name** adds a file to be created at runtime (the file is not overwritten if it already exists)

**file:name=realname** as above but stored under a different name

**dir:name** creates a directory at runtime

**write:new_executable** write a new executable containing the original interpretor and all the added items

When a path starts with `:`, it is relative to the executable path otherwise
it is relative to the current working directory.

`Pegar` class (useable in BonaLuna scripts)
-------------------------------------------

The class `Pegar` defines methods to build an executable.
The methods have the same name as the command line parameters:

**compile(mode)** turns compilation on, off or on

**compress(mode)** turns compression on, off or on

**read(original_interpretor)** reads the initial interpretor (if different from the running interpretor)

**lua(script[, realname])** adds a script to be executed at runtime

**str(name, value)** creates a global variable holding a string

**strf(name, filename)** as above but the string is the content of a file

**file(name[, realname])** adds a file to be created at runtime

**dir(name)** creates a directory at runtime

**write(new_executable)** write a new executable containing the original interpretor and all the added items


External modules
================

Some external modules are available.

- [Lupy](https://github.com/uleelx/lupy): A small Python-style OO implementation
- [Tasks](https://github.com/uleelx/TCP-DNS-proxy): TCP DNS proxy which can get the RIGHT IP address. It includes a multi tasking package


Examples
========

This documentation has been generated by a BonaLuna script.
[bonaluna.lua](bonaluna.lua) also contains some tests.
