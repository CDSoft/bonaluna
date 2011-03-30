/* BonaLuna

Copyright (C) 2010 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 alpha
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

#include "lua.h"

#define BONALUNA_VERSION    "BonaLuna " VERSION
#define BONALUNA_COPYRIGHT  BONALUNA_VERSION " Copyright (C) 2010 cdsoft.fr, Christophe Delord"
#define BONALUNA_AUTHORS    "Christophe Delord"

#define LUA_FSLIBNAME "fs"
LUAMOD_API int (luaopen_fs) (lua_State *L);

#define LUA_PSLIBNAME "ps"
LUAMOD_API int (luaopen_ps) (lua_State *L);

#define LUA_SYSLIBNAME "sys"
LUAMOD_API int (luaopen_sys) (lua_State *L);

#define LUA_STRUCTLIBNAME "struct"
LUAMOD_API int (luaopen_struct) (lua_State *L);
