/* BonaLuna

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

#include "lua.h"

#define BONALUNA_VERSION    "BonaLuna " BL_VERSION
#define BONALUNA_COPYRIGHT  BONALUNA_VERSION " Copyright (C) 2010-2011 cdsoft.fr, Christophe Delord"
#define BONALUNA_AUTHORS    "Christophe Delord"

#if defined(USE_LZO) || defined(USE_QLZ) || defined(USE_LZ4)
    #define USE_LZ
#endif

#if defined(USE_LZO) && (defined(USE_QLZ) || defined(USE_LZ4))
    #define USE_LZO_AND_MORE
#endif
#if defined(USE_QLZ) && (defined(USE_LZO) || defined(USE_LZ4))
    #define USE_QLZ_AND_MORE
#endif
#if defined(USE_LZ4) && (defined(USE_LZO) || defined(USE_QLZ))
    #define USE_LZ4_AND_MORE
#endif

#if defined(USE_LZO_AND_MORE) || defined(USE_QLZ_AND_MORE) || defined(USE_LZ4_AND_MORE)
    #define USE_LZ_TWO_OR_MORE
#endif

#if defined(USE_LZO)
    #define USE_LZO_FIRST
#endif

#if !defined(USE_LZO) && defined(USE_QLZ)
    #define USE_QLZ_FIRST
#endif

#if !defined(USE_LZO) && !defined(USE_QLZ) && defined(USE_LZ4)
    #define USE_LZ4_FIRST
#endif

#define LUA_FSLIBNAME "fs"
LUAMOD_API int (luaopen_fs) (lua_State *L);

#define LUA_PSLIBNAME "ps"
LUAMOD_API int (luaopen_ps) (lua_State *L);

#define LUA_SYSLIBNAME "sys"
LUAMOD_API int (luaopen_sys) (lua_State *L);

#define LUA_STRUCTLIBNAME "struct"
LUAMOD_API int (luaopen_struct) (lua_State *L);

#define LUA_RLLIBNAME "rl"
LUAMOD_API int (luaopen_readline) (lua_State *L);

#define LUA_LZLIBNAME "lz"
LUAMOD_API int (luaopen_lz) (lua_State *L);

#define LUA_CURLLIBNAME "curl"
LUAMOD_API int (luaopen_cURL) (lua_State *L);

#define LUA_CRYPTLIBNAME "crypt"
LUAMOD_API int (luaopen_crypt) (lua_State *L);
