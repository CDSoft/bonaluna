/* BonaLuna

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

#define MAKE_LUA
#define luaall_c
#define lobject_c
#define ltable_c
#define lua_c

/* core */
#include "lapi.c"
#include "lcode.c"
#include "lctype.c"
#include "ldebug.c"
#include "ldo.c"
#include "ldump.c"
#include "lfunc.c"
#include "lgc.c"
#include "llex.c"
#include "lmem.c"
#include "lobject.c"
#include "lopcodes.c"
#include "lparser.c"
#include "lstate.c"
#include "lstring.c"
#include "ltable.c"
#include "ltm.c"
#include "lundump.c"
#include "lvm.c"
#include "lzio.c"

/* auxiliary library */
#include "lauxlib.c"

/* standard library  */
#include "lbaselib.c"
#include "lbitlib.c"
#include "lcorolib.c"
#include "ldblib.c"
#include "liolib.c"
#include "lmathlib.c"
#include "loadlib.c"
#include "loslib.c"
#include "lstrlib.c"
#include "ltablib.c"
#include "linit.c"

/* BonaLuna libraries */
#ifdef USE_MINILZO
#include "minilzo.c"
#endif
#ifdef USE_QLZ
#include "quicklz.c"
#endif
#ifdef USE_LZ4
#include "lz4.c"
#endif
#include "bonaluna.c"
#include "struct.c"
#include "readline.c"
#ifdef USE_CURL
#include "curl.c"
#endif
#ifdef USE_SOCKET
#ifdef _WIN32
#include "wsocket.h"
#else
#include "usocket.h"
#endif
#include "auxiliar.c"
#include "buffer.c"
#include "except.c"
#include "inet.c"
#include "lsio.c"
#include "luasocket.c"
#include "mime.c"
#include "options.c"
#include "select.c"
#include "tcp.c"
#include "timeout.c"
#include "udp.c"
//#include "unix.c"
#ifdef _WIN32
#include "wsocket.c"
#else
#include "usocket.c"
#endif
#endif

/* BonaLuna "glue" */
#include "glue.c"

/* lua */
#include "lua.c"

