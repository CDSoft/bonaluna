/* BonaLuna

Copyright (C) 2010-2020 Christophe Delord
http://cdelord.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2017 Lua.org, PUC-Rio

Freely available under the terms of the MIT license.
*/

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifdef __MINGW32__

/* no readline package for Windows */

#else

#include <readline/readline.h>
#include <readline/history.h>

#endif

static int rl_read(lua_State* L)
{
    const char *prompt = lua_tostring(L, 1);
#ifdef __MINGW32__
    /* io.write(prompt) */
    lua_getglobal(L, "io");         /* push io */
    lua_getfield(L, -1, "write");   /* push io.write */
    lua_remove(L, -2);              /* remove io */
    lua_pushstring(L, prompt);      /* push prompt */
    lua_call(L, 1, 0);              /* call io.write(prompt) */
    /* return io.read "*l" */
    lua_getglobal(L, "io");         /* push io */
    lua_getfield(L, -1, "read");    /* push io.read */
    lua_remove(L, -2);              /* remove io */
    lua_pushstring(L, "*l");        /* push "*l" */
    lua_call(L, 1, 1);              /* call io.read("*l") */
    return 1;
#else
    char *line = readline(prompt);
    char *c;
    for (c = line; *c; c++)
        if (!isspace(*c))
        {
            add_history(line);
            break;
        }
    lua_pushstring(L, line);
    free(line);
    return 1;
#endif
}

static int rl_add(lua_State* L)
{
#ifdef __MINGW32__
    /* no readline history for Windows */
#else
    const char *line = lua_tostring(L, 1);
    const char *c;
    for (c = line; *c; c++)
        if (!isspace(*c))
        {
            add_history(line);
            break;
        }
#endif
    return 0;
}

static const luaL_Reg rllib[] = {
    {"read", rl_read},
    {"add",rl_add},
    {NULL, NULL},
};

LUAMOD_API int luaopen_readline(lua_State *L)
{
    luaL_newlib(L, rllib);
    return 1;
}
