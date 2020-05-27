/* BonaLuna

Copyright (C) 2010-2020 Christophe Delord
http://cdelord.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2017 Lua.org, PUC-Rio

Freely available under the terms of the MIT license.
*/

//#define __USE_GNU

#include "lua.h"

#define BONALUNA_VERSION    "BonaLuna " BL_VERSION
#define BONALUNA_COPYRIGHT  BONALUNA_VERSION " Copyright (C) 2010-2017 cdelord.fr, Christophe Delord"
#define BONALUNA_AUTHORS    "Christophe Delord"

#if defined(USE_MINILZO) || defined(USE_LZO) || defined(USE_QLZ) || defined(USE_LZ4) || defined(USE_LZF) || defined(USE_ZLIB) || defined(USE_UCL) || defined(USE_LZMA)
    #define USE_Z
#endif

LUALIB_API int luaopen_mathx(lua_State *L);

#define LUA_FSLIBNAME "fs"
LUAMOD_API int (luaopen_fs) (lua_State *L);

#define LUA_PSLIBNAME "ps"
LUAMOD_API int (luaopen_ps) (lua_State *L);

#define LUA_SYSLIBNAME "sys"
LUAMOD_API int (luaopen_sys) (lua_State *L);

#define LUA_RLLIBNAME "rl"
LUAMOD_API int (luaopen_readline) (lua_State *L);

#define LUA_LZOLIBNAME "lzo"
LUAMOD_API int (luaopen_lzo) (lua_State *L);

#define LUA_MINILZOLIBNAME "minilzo"
LUAMOD_API int (luaopen_minilzo) (lua_State *L);

#define LUA_QLZLIBNAME "qlz"
LUAMOD_API int (luaopen_qlz) (lua_State *L);

#define LUA_LZ4LIBNAME "lz4"
LUAMOD_API int (luaopen_lz4) (lua_State *L);

#define LUA_LZ4HCLIBNAME "lz4hc"
LUAMOD_API int (luaopen_lz4hc) (lua_State *L);

#define LUA_LZFLIBNAME "lzf"
LUAMOD_API int (luaopen_lzf) (lua_State *L);

#define LUA_ZLIBLIBNAME "zlib"
LUAMOD_API int (luaopen_zlib) (lua_State *L);

#define LUA_UCLLIBNAME "ucl"
LUAMOD_API int (luaopen_ucl) (lua_State *L);

#define LUA_LZMALIBNAME "lzma"
LUAMOD_API int (luaopen_lzma) (lua_State *L);

#define LUA_ZLIBNAME "z"
LUAMOD_API int (luaopen_z) (lua_State *L);

#define LUA_CURLLIBNAME "curl"
LUAMOD_API int (luaopen_cURL) (lua_State *L);

#define LUA_CRYPTLIBNAME "crypt"
LUAMOD_API int (luaopen_crypt) (lua_State *L);

#define LUA_SOCKETLIBNAME "socket"
LUAMOD_API int (luaopen_socket_core) (lua_State *L);

#define LUA_MIMELIBNAME "mime"
LUAMOD_API int (luaopen_mime_core) (lua_State *L);

#define LUA_BCLIBNAME "bc"
LUAMOD_API int (luaopen_bc) (lua_State *L);

#define LUA_LPEGLIBNAME "lpeg"
LUAMOD_API int (luaopen_lpeg) (lua_State *L);
