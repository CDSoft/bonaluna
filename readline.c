// Completely and absolutely minimal binding to the readline library
// Steve Donovan, 2007

// Adapted by Christophe Delord for BonaLuna

#include <stdlib.h> 
#include <string.h> 
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifdef __MINGW32__

/* no readline package for Windows */

#else

#include <readline/readline.h>
#include <readline/history.h>

static int f_readline(lua_State* L)
{
    const char* prompt = lua_tostring(L,1);
    const char* line = readline(prompt);
    lua_pushstring(L,line);
    (void)free((void *)line); // Lua makes a copy...
    return 1;
}

static int f_add_history(lua_State* L)
{
    if (lua_rawlen(L,1) > 0)
        add_history(lua_tostring(L, 1));
    return 0;
}

static const luaL_Reg rllib[] = {
    {"read", f_readline},
    {"add",f_add_history},
    {NULL, NULL},
};

#endif

LUAMOD_API int luaopen_readline (lua_State *L)
{
#ifdef __MINGW32__
    return 0;
#else
    luaL_newlib (L, rllib);
    return 1;
#endif
}
