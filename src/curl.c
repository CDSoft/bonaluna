/* Based on Lua-cURL                                          */
/* https://github.com/juergenhoetzel/Lua-cURL/tree/master/src */
/* Adapted for BunaLuna                                       */

/******************************************************************************
* Copyright (C) 2007 Juergen Hoetzel
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

/*****************************************************************************/
/* Lua-cURL.h                                                                */
/*****************************************************************************/

#ifndef LUACURL_H
#define LUACURL_H

/* lua specific */
#include <lua.h>
#include <lauxlib.h>

/* curl specific */
#include <curl/curl.h>
#include <curl/easy.h>

/* custom metatables */
#define LUACURL_EASYMETATABLE "CURL.easy"
#define LUACURL_MULTIMETATABLE "CURL.multi"
#define LUACURL_SHAREMETATABLE "CURL.shared"
#define LUACURL_REGISTRYPREFIX "Lua-cURL_private"

#define MULTIREGISTRY_KEY "_LUA_CURL"

/* custom macros */
#define LUACURL_CHECKEASY(L) (CURL *) luaL_checkudata(L, 1, LUACURL_EASYMETATABLE)
#define LUACURL_OPTIONP_UPVALUE(L, INDEX) ((CURLoption *) lua_touserdata(L, lua_upvalueindex(INDEX)))
#define LUACURL_INFOP_UPVALUE(L, INDEX) ((CURLINFO *) lua_touserdata(L, lua_upvalueindex(INDEX)))

typedef struct l_option_slist {
    CURLoption option;
    struct curl_slist *slist;
} l_option_slist;

typedef struct l_easy_private {
  CURL *curl;
  char error[CURL_ERROR_SIZE];

  /* slists, allocated by l_easy_setopt_strings */
  l_option_slist *option_slists;
} l_easy_private;

/* Lua closures (CURL* upvalue) */
int l_tostring (lua_State *L);

/* setopt closures */
int l_easy_opt_long (lua_State *L);
int l_easy_opt_string (lua_State *L);

/* easy interface */
int l_easy_escape (lua_State *L);
int l_easy_init (lua_State *L);
int l_easy_perform (lua_State *L);
int l_easy_unescape (lua_State *L);
int l_easy_post(lua_State *L);
 int l_easy_userdata(lua_State *L);

/* multi interface */
int l_multi_init (lua_State *L);
int l_multi_add_handle (lua_State *L);
int l_multi_perform (lua_State *L);
int l_multi_gc (lua_State *L);

/* shared interface */
int l_share_init (lua_State *L);
int l_share_setopt_share(lua_State *L);
int l_share_gc (lua_State *L);

/* subtable creation */
int l_easy_getinfo_register (lua_State *L);
int l_easy_setopt_register (lua_State *L);
int l_easy_callback_newtable(lua_State *L);

/* init private list of curl_slists */
void  l_easy_setopt_init_slists(lua_State *L, l_easy_private *privp);
void l_easy_setopt_free_slists(l_easy_private *privp);

/* setup callback function */
int l_easy_setup_writefunction(lua_State *L, CURL* curl);
int l_easy_setup_headerfunction(lua_State *L, CURL* curl);
int l_easy_setup_readfunction(lua_State *L, CURL* curl);
int l_easy_clear_headerfunction(lua_State *L, CURL* curl);
int l_easy_clear_writefunction(lua_State *L, CURL* curl);
int l_easy_clear_readfunction(lua_State *L, CURL* curl);

/* Lua module functions */
int l_easy_init (lua_State *L);
int l_getdate (lua_State *L);
int l_unescape (lua_State *L);
int l_version (lua_State *L);
int l_version_info (lua_State *L);

/* Lua metatable functions */
int l_tostring (lua_State *L);
int l_easy_gc (lua_State *L);
int l_setopt(lua_State *L);
int l_getopt(lua_State *L);

#endif

/*****************************************************************************/
/* Lua-cURL-share.h                                                          */
/*****************************************************************************/

#ifndef LUA_CURL_SHARE_H
#define LUA_CURL_SHARE_H

typedef struct l_share_userdata {
  CURLSH *curlsh;
} l_share_userdata;

#endif

/*****************************************************************************/
/* Lua-utility.h                                                             */
/*****************************************************************************/

#ifndef LUA_UTILITY_H
#define LUA_UTILITY_H

#include <lua.h>

#define luaL_checktable(L, n) luaL_checktype(L, n, LUA_TTABLE)
/* return NULL if key doesnt exist */
const char* luaL_getstrfield(lua_State* L, const char* key);
const char* luaL_getlstrfield(lua_State* L, const char* key, int *len);

#define stackDump(L) _stackDump(L, __FILE__, __LINE__)
void _stackDump (lua_State *L, const char* file, int line);

#endif

/*****************************************************************************/
/* Lua-cURL.c                                                                */
/*****************************************************************************/

//#include "Lua-cURL.h"
//#include "Lua-utility.h"

/* malloc */
#include <stdlib.h>

/* methods assigned to easy table */
static const struct luaL_Reg luacurl_easy_m[] = {
  {"escape", l_easy_escape},
  {"perform", l_easy_perform},
  {"unescape", l_easy_unescape},
  {"post", l_easy_post},
  {"__gc", l_easy_gc},
  /* not for public use */
  {NULL, NULL}};

/* methods assigned to multi table */
static const struct luaL_Reg luacurl_multi_m[] = {
  {"add_handle", l_multi_add_handle},
  {"perform", l_multi_perform},
  {"__gc", l_multi_gc},
  {NULL, NULL}};

static const struct luaL_Reg luacurl_share_m[] = {
  {"setopt_share", l_share_setopt_share},
  {"__gc", l_share_gc},
  {NULL, NULL}};

/* global functions in module namespace*/
static const struct luaL_Reg luacurl_f[] = {
  {"easy_init", l_easy_init},
  {"multi_init", l_multi_init},
  {"share_init", l_share_init},
  {"getdate", l_getdate},
  {"unescape", l_unescape},
  {"version", l_version},
  {"version_info", l_version_info},
  {NULL, NULL}};

/* functions assigned to metatable */
static const struct luaL_Reg luacurl_m[] = {

  {NULL, NULL}};

int l_easy_escape(lua_State *L) {
  size_t length = 0;
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  const char *url = luaL_checklstring(L, 2, &length);
  char *rurl = curl_easy_escape(curl, url, length);
  lua_pushstring(L, rurl);
  curl_free(rurl);
  return 1;
}


int l_easy_perform(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  /* do writecallback? */
  int writefunction;
  /* do headercallback */
  int headerfunction;
  /* do readcallback */
  int readfunction;

  /* check optional callback table */
  luaL_opt(L, luaL_checktable, 2, lua_newtable(L));

  /* setup write callback function only if entry exists in callback-table */
  lua_getfield(L, 2, "writefunction");
  writefunction =  lua_isfunction(L, -1)?1:0;
  if (writefunction)
    l_easy_setup_writefunction(L, privatep->curl);
  lua_pop(L, 1);

  /* setup header callback function only if entry exists in callback-table */
  lua_getfield(L, 2, "headerfunction");
  headerfunction = lua_isfunction(L, -1)?1:0;
  if (headerfunction)
    l_easy_setup_headerfunction(L, privatep->curl);
  lua_pop(L, 1);

  /* setup read callback function only if entry exists in callback-table */
  lua_getfield(L, 2, "readfunction");
  readfunction = lua_isfunction(L, -1)?1:0;
  if (readfunction)
    l_easy_setup_readfunction(L, privatep->curl);
  lua_pop(L, 1);


  /* callback table is on top on stack */
  int r = curl_easy_perform(curl);
  
  /* unset callback functions */
  if (headerfunction)
    l_easy_clear_headerfunction(L, privatep->curl);
  if (writefunction)
    l_easy_clear_writefunction(L, privatep->curl);
  if (readfunction)
    l_easy_clear_readfunction(L, privatep->curl);

  if (r != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }
  lua_pushboolean(L, 1);
  return 1;
}

int l_easy_init(lua_State *L) {
  l_easy_private *privp;

  /* create userdata and assign metatable */
  privp = (l_easy_private *) lua_newuserdata(L, sizeof(l_easy_private));

  /* allocate list of curl_slist for setopt handling */
  l_easy_setopt_init_slists(L, privp);

  luaL_getmetatable(L, LUACURL_EASYMETATABLE);
  lua_setmetatable(L, - 2);

  if ((privp->curl = curl_easy_init()) == NULL)
    return luaL_error(L, "something went wrong and you cannot use the other curl functions");

  /* set error buffer */
  if (curl_easy_setopt(privp->curl, CURLOPT_ERRORBUFFER, privp->error) != CURLE_OK)
    return luaL_error(L, "cannot set error buffer");

  /* return userdata; */
  return 1;
}

int l_getdate(lua_State *L) {
  const char *date = luaL_checkstring(L, 1);
  time_t t = curl_getdate(date, NULL);
  if (t == -1)
  {
    lua_pushnil(L);
    lua_pushstring(L, "fails to parse the date string");
    return 2;
  }
  lua_pushinteger(L, t);
  return 1;
}


int l_easy_unescape(lua_State *L) {
  size_t inlength = 0;
  int outlength;
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  const char *url = luaL_checklstring(L, 2, &inlength);
  char *rurl = curl_easy_unescape(curl, url, inlength, &outlength);
  lua_pushlstring(L, rurl, outlength);
  curl_free(rurl);
  return 1;
}

/* deprecated */
int l_unescape(lua_State *L) {
  size_t length;
  const char *url = luaL_checklstring(L, 1, &length);
  char *rurl = curl_unescape(url, length);
  lua_pushstring(L, rurl);
  curl_free(rurl);
  return 1;
}


int l_version(lua_State *L) {
  lua_pushstring(L, curl_version());
  return 1;
}

int l_version_info (lua_State *L) {
  int i;
  curl_version_info_data *d = curl_version_info(CURLVERSION_NOW);
  struct {char *name; int bitmask;} features[] = {
    {"ipv6", CURL_VERSION_IPV6},
    {"kerberos4", CURL_VERSION_KERBEROS4},
    {"ssl", CURL_VERSION_SSL},
    {"libz", CURL_VERSION_LIBZ},
    {"ntlm",CURL_VERSION_NTLM},
    {"gssnegotiate",CURL_VERSION_GSSNEGOTIATE},
    {"debug",CURL_VERSION_DEBUG},
    {"asynchdns",CURL_VERSION_ASYNCHDNS},
    {"spnego",CURL_VERSION_SPNEGO},
    {"largefile",CURL_VERSION_LARGEFILE},
    {"idn",CURL_VERSION_IDN},
    {"sspi",CURL_VERSION_SSPI},
    {"conv",CURL_VERSION_CONV},
    {NULL, 0}
  };



  lua_newtable(L);

  lua_pushliteral(L, "version");
  lua_pushstring(L, d->version);
  lua_settable(L, -3);

  lua_pushliteral(L, "version_num");
  lua_pushinteger(L, d->version_num);
  lua_settable(L, -3);

  lua_pushliteral(L, "host");
  lua_pushstring(L, d->host);
  lua_settable(L, -3);

  /* create features table */
  lua_pushliteral(L, "features");
  lua_newtable(L);

  i = 0;
  while (features[i].name != NULL) {
    lua_pushboolean(L, d->features & features[i].bitmask);
    lua_setfield(L, -2, features[i++].name);
  }

  lua_settable(L, -3);

  /* ssl */
  lua_pushliteral(L, "ssl_version");
  lua_pushstring(L, d->ssl_version);
  lua_settable(L, -3);

  lua_pushliteral(L, "libz_version");
  lua_pushstring(L, d->libz_version);
  lua_settable(L, -3);

  /* create protocols table*/
  lua_pushstring(L,"protocols");
  lua_newtable(L);

  for(i=0; d->protocols[i] != NULL; i++){
    lua_pushinteger(L, i+1);
    lua_pushstring(L, d->protocols[i]);
    lua_settable(L, -3);
  }

  lua_settable(L, -3);

  if (d->age >= 1) {
    lua_pushliteral(L, "ares");
    lua_pushstring(L, d->ares);
    lua_settable(L, -3);

    lua_pushliteral(L, "ares_num");
    lua_pushinteger(L, d->ares_num);
    lua_settable(L, -3);
  }

  if (d->age >= 2) {
    lua_pushliteral(L, "libidn");
    lua_pushstring(L, d->libidn);
    lua_settable(L, -3);
  }

  if (d->age >= 3) {
    lua_pushliteral(L, "iconv_ver_num");
    lua_pushinteger(L, d->iconv_ver_num);
    lua_settable(L, -3);
  }

  /* return table*/
  return 1;
}

int l_easy_gc(lua_State *L) {
  /* gc resources optained by cURL userdata */
  l_easy_private *privp = lua_touserdata(L, 1);
  curl_easy_cleanup(privp->curl);
  l_easy_setopt_free_slists(privp);
  return 0;
}

/* registration hook function */
int luaopen_cURL(lua_State *L) {
  CURLcode  rc;

  /* EASY START */
  luaL_newmetatable(L, LUACURL_EASYMETATABLE);

  /* register in easymetatable */
  //luaL_register(L, NULL, luacurl_easy_m);
  luaL_setfuncs(L, luacurl_easy_m, 0);

  /* easymetatable.__index = easymetatable */
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  /* register getinfo closures  */
  l_easy_getinfo_register(L);
  /* register setopt closures  */
  l_easy_setopt_register(L);


  /* SHARE START */
  luaL_newmetatable(L, LUACURL_SHAREMETATABLE);

  /* register in sharemetatable */
  //luaL_register(L, NULL, luacurl_share_m);
  luaL_setfuncs(L, luacurl_share_m, 0);

  /* sharemetatable.__index = sharemetatable */
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  /* MULTI START */
  luaL_newmetatable(L, LUACURL_MULTIMETATABLE);
  //luaL_register(L, NULL, luacurl_multi_m);
  luaL_setfuncs(L, luacurl_multi_m, 0);
    /* multemetatable.__index = multimetatable */
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");


  /* creaty uniqe table in registry to store state */
  lua_newtable(L);
  lua_setfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pop(L, 1);        /* pop table */


  /* return module functions */
  //luaL_register(L, "cURL", luacurl_f);
  luaL_newlib(L, luacurl_f);

  /* initialize curl once */
  if ((rc = curl_global_init(CURL_GLOBAL_ALL)) != CURLE_OK)
    luaL_error(L, "curl_global_init: %s", curl_easy_strerror(rc));
  return 1;
}

/*****************************************************************************/
/* Lua-cURL-callback.c                                                       */
/*****************************************************************************/

#include <string.h>     /* memcpy */

//#include "Lua-cURL.h"
//#include "Lua-utility.h"

static size_t l_easy_readfunction(void *ptr, size_t size, size_t nmemb, void *stream) {
  lua_State* L = (lua_State*)stream;
  size_t n;
  int old_top = lua_gettop(L);
  const char *str;
  lua_getfield(L, -1, "readfunction");
  lua_pushinteger(L, nmemb * size);
  lua_call(L, 1, 1);
  str = lua_tolstring(L, -1, &n);
  if (n > nmemb*size)
    luaL_error(L, "String returned from readfunction is too long (%d)", n);
  memcpy(ptr, str, n);
  lua_settop(L, old_top);
  return n;
}

static size_t l_easy_writefunction(void *ptr, size_t size, size_t nmemb, void *stream) {
  lua_State* L = (lua_State*)stream;

  lua_getfield(L, -1, "writefunction");
  lua_pushlstring(L, (char*) ptr, nmemb * size);
  lua_call(L, 1, 0);
  return nmemb*size;
}

static size_t l_easy_headerfunction(void *ptr, size_t size, size_t nmemb, void *stream) {
  lua_State* L = (lua_State*)stream;
  lua_getfield(L, -1, "headerfunction");
  lua_pushlstring(L, (char*) ptr, nmemb * size);
  lua_call(L, 1, 0);
  return nmemb*size;
}


int l_easy_setup_writefunction(lua_State *L, CURL* curl) {
    /* Lua State as userdata argument */
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_WRITEDATA ,L) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  if (curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, l_easy_writefunction) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

int l_easy_setup_readfunction(lua_State *L, CURL* curl) {
    /* Lua State as userdata argument */
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_READDATA ,L) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  if (curl_easy_setopt(curl, CURLOPT_READFUNCTION, l_easy_readfunction) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

int l_easy_setup_headerfunction(lua_State *L, CURL* curl) {
  /* Lua State as userdata argument */
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_WRITEHEADER ,L) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);

  if (curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, l_easy_headerfunction) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

int l_easy_clear_headerfunction(lua_State *L, CURL* curl) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, NULL) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

int l_easy_clear_writefunction(lua_State *L, CURL* curl) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NULL) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

int l_easy_clear_readfunction(lua_State *L, CURL* curl) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  if (curl_easy_setopt(curl, CURLOPT_READFUNCTION, NULL) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}
/*****************************************************************************/
/* Lua-cURL-getinfo.c                                                        */
/*****************************************************************************/

//#include "Lua-cURL.h"
//#include "Lua-utility.h"

/* prefix of all registered functions */
#define P "getinfo_"

static int l_easy_getinfo_string(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLINFO *infop = LUACURL_INFOP_UPVALUE(L, 1);
  char *value;

  if (curl_easy_getinfo(curl, *infop, &value) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }

  lua_pushstring(L, value);
  return 1;
}

static int l_easy_getinfo_long(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLINFO *infop = LUACURL_INFOP_UPVALUE(L, 1);
  long value;

  if (curl_easy_getinfo(curl, *infop, &value) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }

  lua_pushinteger(L, value);
  return 1;
}

static int l_easy_getinfo_double(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLINFO *infop = LUACURL_INFOP_UPVALUE(L, 1);
  double value;

  if (curl_easy_getinfo(curl, *infop, &value) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }

  lua_pushnumber(L, value);
  return 1;
}

static int l_easy_getinfo_curl_slist(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLINFO *infop = LUACURL_INFOP_UPVALUE(L, 1);
  struct curl_slist *list;
  struct curl_slist *next;
  int i;

  if (curl_easy_getinfo(curl, *infop, &list) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }

  i = 1;
  next = list;
  lua_newtable(L);

  while (next) {
    lua_pushstring(L, (char*) next->data);
    lua_rawseti(L, -2, i++);
    next = next->next;
  }

  curl_slist_free_all(list);

  return 1;
}

static struct {
  const char *name;
  CURLINFO info;
  lua_CFunction func;
} luacurl_getinfo_c[] = {
  {P"effective_url", CURLINFO_EFFECTIVE_URL, l_easy_getinfo_string},
  {P"response_code", CURLINFO_RESPONSE_CODE, l_easy_getinfo_long},
  {P"http_connectcode", CURLINFO_HTTP_CONNECTCODE, l_easy_getinfo_long},
  {P"filetime", CURLINFO_FILETIME, l_easy_getinfo_long},
  {P"total_time", CURLINFO_TOTAL_TIME, l_easy_getinfo_double},
  {P"namelookup_time", CURLINFO_NAMELOOKUP_TIME, l_easy_getinfo_double},
  {P"connect_time", CURLINFO_CONNECT_TIME, l_easy_getinfo_double},
  {P"pretransfer", CURLINFO_PRETRANSFER_TIME, l_easy_getinfo_double},
  {P"starttransfer_time", CURLINFO_STARTTRANSFER_TIME, l_easy_getinfo_double},
  {P"redirect_time", CURLINFO_REDIRECT_TIME, l_easy_getinfo_double},
  {P"redirect_count", CURLINFO_REDIRECT_COUNT, l_easy_getinfo_long},
  {P"size_upload", CURLINFO_SIZE_UPLOAD, l_easy_getinfo_double},
  {P"size_download", CURLINFO_SIZE_DOWNLOAD, l_easy_getinfo_double},
  {P"speed_download", CURLINFO_SPEED_DOWNLOAD, l_easy_getinfo_double},
  {P"speed_upload", CURLINFO_SPEED_UPLOAD, l_easy_getinfo_double},
  {P"header_size", CURLINFO_HEADER_SIZE, l_easy_getinfo_long},
  {P"request_size", CURLINFO_REQUEST_SIZE, l_easy_getinfo_long},
  {P"ssl_verifyresult", CURLINFO_SSL_VERIFYRESULT, l_easy_getinfo_long},
  {P"ssl_engines", CURLINFO_SSL_ENGINES, l_easy_getinfo_curl_slist},
  {P"content_length_download", CURLINFO_CONTENT_LENGTH_DOWNLOAD, l_easy_getinfo_double},
  {P"content_length_upload", CURLINFO_CONTENT_LENGTH_UPLOAD, l_easy_getinfo_double},
  {P"content_type", CURLINFO_CONTENT_TYPE, l_easy_getinfo_string},
  {P"private", CURLINFO_PRIVATE, l_easy_getinfo_string},
  {P"httpauth_avail", CURLINFO_HTTPAUTH_AVAIL, l_easy_getinfo_long},
  {P"proxyauth_avail", CURLINFO_PROXYAUTH_AVAIL, l_easy_getinfo_long},
  {P"os_errno", CURLINFO_OS_ERRNO, l_easy_getinfo_long},
  {P"num_connects", CURLINFO_NUM_CONNECTS, l_easy_getinfo_long},
  {P"cookielist", CURLINFO_COOKIELIST, l_easy_getinfo_curl_slist},
  {P"lastsocket", CURLINFO_LASTSOCKET, l_easy_getinfo_long},
  {P"ftp_entry_path" , CURLINFO_FTP_ENTRY_PATH , l_easy_getinfo_string},
  {NULL, CURLINFO_EFFECTIVE_URL, NULL}};


int l_easy_getinfo_register(lua_State *L) {
  int i;

  /* register getinfo closures */
  for (i=0; luacurl_getinfo_c[i].name != NULL; i++) {
    CURLINFO *infop = &(luacurl_getinfo_c[i].info);
    lua_pushlightuserdata(L, infop);
    lua_pushcclosure(L, luacurl_getinfo_c[i].func, 1);
    lua_setfield(L, -2, luacurl_getinfo_c[i].name);
  }

  return 0;
}

#undef P

/*****************************************************************************/
/* Lua-cURL-multi.c                                                          */
/*****************************************************************************/

#include <stdlib.h>     /* malloc */
#ifndef __WIN32__
#include <sys/select.h>     /* select */
#else
#include <winsock2.h>
#endif
#include <string.h>     /* strerror */
#include <errno.h>

//#include "Lua-cURL.h"
//#include "Lua-utility.h"

/* REGISTRYINDEX[MULTIREGISTRY_KEY]  = {
   MULTIPOINTER = { 1={ 1=type, 2=data, 3=EASY_HANDLE}
                  { 2={ 1=type, 2=data, 3=EASY_HANDLE}
   EASYPOINTER1 = {EASYUSERDATA1}
   EASYPOINTER2 = {EASYPOINTER2}
}
 */

typedef struct l_multi_userdata {
  CURLM *curlm;
  int last_remain;          /* remaining easy sockets */
  int n_easy;               /* number of easy handles */
} l_multi_userdata;


typedef struct l_multi_callbackdata {
  lua_State* L;
  l_easy_private *easyp;        /* corresponding easy handler */
  l_multi_userdata *multip;     /* corresponding easy handler */
  char *name;           /* type: header/write */
} l_multi_callbackdata;

#define LUACURL_PRIVATE_MULTIP_UPVALUE(L, INDEX) ((l_multi_userdata *) lua_touserdata(L, lua_upvalueindex(INDEX)))

static l_multi_userdata* l_multi_newuserdata(lua_State *L) {
  l_multi_userdata *multi_userdata = (l_multi_userdata *) lua_newuserdata(L, sizeof(l_multi_userdata));
  multi_userdata->n_easy = 0;
  multi_userdata->last_remain = 1;      /* dummy: not null */
  luaL_getmetatable(L, LUACURL_MULTIMETATABLE);
  lua_setmetatable(L, -2);
  return multi_userdata;
}


int l_multi_init(lua_State *L) {

  l_multi_userdata *multi_userdata = l_multi_newuserdata(L);

  if ((multi_userdata->curlm = curl_multi_init()) == NULL)
    luaL_error(L, "something went wrong and you cannot use the other curl functions");

  /* creaty uniqe table in registry to store state for callback functions */
  lua_getfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pushlightuserdata(L, multi_userdata);
  lua_newtable(L);
  lua_settable(L, -3);
  lua_pop(L, 1);
  /* return userdata */
  return 1;
}

static size_t l_multi_internalcallback(void *ptr, size_t size, size_t nmemb, void *stream) {
  l_multi_callbackdata *callbackdata = (l_multi_callbackdata*) stream;
  /* append data */
  lua_State *L = callbackdata->L;

  /* table.insert(myregistrytable, {callbackdata}) */
  lua_getglobal(L, "table");
  lua_getfield(L, -1, "insert");
  /* remove table reference */
  lua_remove(L, -2);

  lua_getfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pushlightuserdata(L, callbackdata->multip);
  lua_gettable(L, -2);
  /* remove registry table */
  lua_remove(L, -2);

  /* create new table containing callbackdata */
  lua_newtable(L);
  /* insert table entries */
  /* data */
  lua_pushlstring(L, ptr, size * nmemb);
  lua_rawseti(L, -2 , 1);
  /* type */
  lua_pushstring(L, callbackdata->name);
  lua_rawseti(L, -2 , 2);

  /* get corresponding easyuserdata */
  lua_getfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pushlightuserdata(L, callbackdata->multip);
  lua_gettable(L, -2);
  /* remove registry table */
  lua_remove(L, -2);
  lua_pushlightuserdata(L, callbackdata->easyp);
  lua_gettable(L, -2);
  lua_remove(L, - 2);
  lua_rawseti(L, -2 , 3);

  lua_call(L, 2, 0);
  return nmemb*size;
}

l_multi_callbackdata* l_multi_create_callbackdata(lua_State *L, char *name, l_easy_private *easyp, l_multi_userdata *multip) {
  l_multi_callbackdata *callbackdata;

  /* TODO: sanity check */
  /*   luaL_error(L, "callbackdata exists: %d, %s", easyp, name); */

  /* shrug! we need to garbage-collect this */
  callbackdata = (l_multi_callbackdata*) malloc(sizeof(l_multi_callbackdata));
  if (callbackdata == NULL)
    luaL_error(L, "can't malloc callbackdata");

  /* initialize */
  callbackdata->L = L;
  callbackdata->name = name;
  callbackdata->easyp = easyp;
  callbackdata->multip = multip;
  /* add to list of callbackdata */
  return callbackdata;
}

int l_multi_add_handle (lua_State *L) {
  l_multi_userdata *privatep = luaL_checkudata(L, 1, LUACURL_MULTIMETATABLE);
  CURLM *curlm = privatep->curlm;
  CURLMcode rc;
  l_multi_callbackdata *data_callbackdata, *header_callbackdata;

  /* get easy userdata */
  l_easy_private *easyp = luaL_checkudata(L, 2, LUACURL_EASYMETATABLE);

  if ((rc = curl_multi_add_handle(curlm, easyp->curl)) != CURLM_OK)
    luaL_error(L, "cannot add handle: %s", curl_multi_strerror(rc));

  /* Add To registry  */
  lua_getfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pushlightuserdata(L, privatep);
  lua_gettable(L, -2);
  /* remove registry table */
  lua_remove(L, -2);
  lua_pushlightuserdata(L, easyp);
  lua_pushvalue(L, 2);
  lua_settable(L, -3);
  /* remove multiregistry table from stack */
  lua_pop(L, 1);

  privatep->n_easy++;
  data_callbackdata = l_multi_create_callbackdata(L, "data", easyp, privatep);
  /* setup internal callback */
  if (curl_easy_setopt(easyp->curl, CURLOPT_WRITEDATA , data_callbackdata) != CURLE_OK)
    luaL_error(L, "%s", easyp->error);
  if (curl_easy_setopt(easyp->curl, CURLOPT_WRITEFUNCTION, l_multi_internalcallback) != CURLE_OK)
    luaL_error(L, "%s", easyp->error);

  /* shrug! we need to garbage-collect this */
  header_callbackdata = l_multi_create_callbackdata(L, "header", easyp, privatep);
  if (curl_easy_setopt(easyp->curl, CURLOPT_WRITEHEADER , header_callbackdata) != CURLE_OK)
    luaL_error(L, "%s", easyp->error);
  if (curl_easy_setopt(easyp->curl, CURLOPT_WRITEFUNCTION, l_multi_internalcallback) != CURLE_OK)
    luaL_error(L, "%s", easyp->error);
  return 0;
}

/* try to get data from internall callbackbuffer */
static int l_multi_perform_internal_getfrombuffer(lua_State *L, l_multi_userdata *privatep) {
  /* table.remove(myregistrytable, 1) */
  lua_getglobal(L, "table");
  lua_getfield(L, -1, "remove");
  /* remove table reference */
  lua_remove(L, -2);

  /* get callback table */
  lua_getfield(L, LUA_REGISTRYINDEX, MULTIREGISTRY_KEY);
  lua_pushlightuserdata(L, privatep);
  lua_gettable(L, -2);
  /* remove table  */
  lua_remove(L, -2);

  lua_pushinteger(L, 1);
  lua_call(L, 2, 1);
  return 1;
}

static int l_multi_perform_internal (lua_State *L) {
  l_multi_userdata *privatep = LUACURL_PRIVATE_MULTIP_UPVALUE(L, 1);
  CURLM *curlm = privatep->curlm;
  CURLMcode rc;
  int remain;
  int n;

  l_multi_perform_internal_getfrombuffer(L, privatep);
  /* no data in buffer: try another perform */
  while (lua_isnil(L, -1)) {
    lua_pop(L, -1);
    if (privatep->last_remain == 0)
      return 0;         /* returns nil*/

   while ((rc = curl_multi_perform(curlm, &remain)) == CURLM_CALL_MULTI_PERFORM); /* loop */
    if (rc != CURLM_OK)
      luaL_error(L, "cannot perform: %s", curl_multi_strerror(rc));
    privatep->last_remain = remain;

    /* got data ? */
    l_multi_perform_internal_getfrombuffer(L, privatep);
    /* block for more data */
    if (lua_isnil(L, -1) && remain) {
      fd_set fdread;
      fd_set fdwrite;
      fd_set fdexcep;
      int maxfd;

      FD_ZERO(&fdread);
      FD_ZERO(&fdwrite);
      FD_ZERO(&fdexcep);

      if ((rc = curl_multi_fdset(curlm, &fdread, &fdwrite, &fdexcep, &maxfd)) != CURLM_OK)
    luaL_error(L, "curl_multi_fdset: %s", curl_multi_strerror(rc));


      if ((n = select(maxfd+1, &fdread, &fdwrite, &fdexcep, NULL)) < 0)
    luaL_error(L, "select: %s", strerror(errno));
    }
  }
  /* unpack table */

  n = lua_gettop(L);
  lua_rawgeti(L, n, 1);     /* data */
  lua_rawgeti(L, n, 2);     /* type */
  lua_rawgeti(L, n, 3);     /* easy */
  lua_remove(L, n);
  return 3;
}
/* return closure */
int l_multi_perform (lua_State *L) {
  luaL_checkudata(L, 1, LUACURL_MULTIMETATABLE);
  lua_pushcclosure(L, l_multi_perform_internal, 1);
  return 1;
}

int l_multi_gc (lua_State *L) {
  l_multi_userdata *privatep = luaL_checkudata(L, 1, LUACURL_MULTIMETATABLE);
  /*   printf("Not implemented: have to cleanup easyhandles: %d\n", privatep->n_easy); */
  return 0;
}

/*****************************************************************************/
/* Lua-cURL-post.c                                                           */
/*****************************************************************************/

/*
 * call-seq:
 *   easy.http_post("url=encoded%20form%20data;and=so%20on") => true
 *   easy.http_post("url=encoded%20form%20data", "and=so%20on", ...) => true
 *   easy.http_post("url=encoded%20form%20data", Curl::PostField, "and=so%20on", ...) => true
 *   easy.http_post(Curl::PostField, Curl::PostField ..., Curl::PostField) => true
 *
 * POST the specified formdata to the currently configured URL using
 * the current options set for this Curl::Easy instance. This method
 * always returns true, or raises an exception (defined under
 * Curl::Err) on error.
 *
 * The Content-type of the POST is determined by the current setting
 * of multipart_form_post? , according to the following rules:
 * * When false (the default): the form will be POSTed with a
 *   content-type of 'application/x-www-form-urlencoded', and any of the
 *   four calling forms may be used.
 * * When true: the form will be POSTed with a content-type of
 *   'multipart/formdata'. Only the last calling form may be used,
 *   i.e. only PostField instances may be POSTed. In this mode,
 *   individual fields' content-types are recognised, and file upload
 *   fields are supported.
 *
 */


/* only url-encoded at the moment */

//#include "Lua-cURL.h"
//#include "Lua-utility.h"

int l_easy_post(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  int index_next, index_table, index_key;
  const char *value, *key;


  struct curl_httppost* post = NULL;
  struct curl_httppost* last = NULL;

  /* param verification */
  luaL_checktable(L, 2);

  lua_getglobal(L, "pairs");
  lua_pushvalue(L, 2);
  lua_call(L, 1, 3);

  /* got next, t, k on stack */
  index_key = lua_gettop(L);
  index_table = index_key - 1;
  index_next = index_table - 1;

  while (1) {
    lua_pushvalue(L, index_next);
    lua_pushvalue(L, index_table);
    lua_pushvalue(L, index_key);

    lua_call(L, 2, 2);
    if (lua_isnil(L, -2))
      break;

    /* duplicate key before converting to string (we need the original type for the iter function) */
    lua_pushvalue(L, -2);
    key = lua_tostring(L, -1);
    lua_pop(L, 1);

    /* got {name = {file="/tmp/test.txt",
                    type="text/plain"}}
       or  {name = {file="dummy.html",
                    data="<html><bold>bold</bold></html>,
                    type="text/html"}}
    */
    if (lua_istable(L, -1)) {
      const char* type, *file, *data;
      CURLFORMcode rc = CURLE_OK;
      int datalen;

      /* check for type option */
      type = luaL_getstrfield(L, "type");

      /* check for file option */
      file = luaL_getstrfield(L, "file");

      /* check for data option */
      data = luaL_getlstrfield(L, "data", &datalen);

      /* file upload */
      if ((file != NULL) && (data == NULL)) {
    rc = (type == NULL)?
      curl_formadd(&post, &last, CURLFORM_COPYNAME, key,
               CURLFORM_FILE, file, CURLFORM_END):
      curl_formadd(&post, &last, CURLFORM_COPYNAME, key,
               CURLFORM_FILE, file,
               CURLFORM_CONTENTTYPE, type, CURLFORM_END);
      }
      /* data field */
      else if ((file != NULL) && (data != NULL)) {
    /* Add a buffer to upload */
    rc = (type != NULL)?
      curl_formadd(&post, &last,
               CURLFORM_COPYNAME, key,
               CURLFORM_BUFFER, file, CURLFORM_BUFFERPTR, data, CURLFORM_BUFFERLENGTH, datalen,
               CURLFORM_CONTENTTYPE, type,
               CURLFORM_END):
      curl_formadd(&post, &last,
               CURLFORM_COPYNAME, key,
               CURLFORM_BUFFER, file, CURLFORM_BUFFERPTR, data, CURLFORM_BUFFERLENGTH, datalen,
               CURLFORM_END);
      }
      else
    luaL_error(L, "Mandatory: \"file\"");
      if (rc != CURLE_OK)
    luaL_error(L, "cannot add form: %s", curl_easy_strerror(rc));
    }
    /* go name=value */
    else {
      value = luaL_checkstring(L, -1);
      /* add name/content section */
      curl_formadd(&post, &last, CURLFORM_COPYNAME, key, CURLFORM_COPYCONTENTS, value, CURLFORM_END);
    }

    /* remove value */
    lua_pop(L, 1);
    /* move key */
    lua_replace(L, index_key);
  }

  curl_easy_setopt(curl, CURLOPT_HTTPPOST, post);
  return 0;
}

/*****************************************************************************/
/* Lua-cURL-setopt.c                                                         */
/*****************************************************************************/

#include <string.h>

//#include "Lua-cURL.h"
//#include "Lua-cURL-share.h"
//#include "Lua-utility.h"

#define P "setopt_"

static int l_easy_setopt_long(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLoption *optionp = LUACURL_OPTIONP_UPVALUE(L, 1);
  long value = luaL_checklong(L,2);

  if (curl_easy_setopt(curl, *optionp, value) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

static int l_easy_setopt_string(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLoption *optionp = LUACURL_OPTIONP_UPVALUE(L, 1);
  const char *value = luaL_checkstring(L, 2);

  if (curl_easy_setopt(curl, *optionp, value) != CURLE_OK)
    luaL_error(L, "%s", privatep->error);
  return 0;
}

void l_easy_setopt_free_slist(l_easy_private *privp, CURLoption option) {
  int i = 0;

  while (privp->option_slists[i].option != 0) {
    if (privp->option_slists[i].option == option) {
      /* free existing slist for this option */
      if (privp->option_slists[i].slist != NULL) {
    curl_slist_free_all(privp->option_slists[i].slist);
    privp->option_slists[i].slist = NULL;
      }
      break;
    }
    i++;
  }
}

struct curl_slist**  l_easy_setopt_get_slist(l_easy_private *privp, CURLoption option) {
 int i = 0;

 while (privp->option_slists[i].option != 0) {
   if (privp->option_slists[i].option == option)
     return &(privp->option_slists[i].slist);
   i++;
 }
 return NULL;
}

static int l_easy_setopt_strings(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLoption *optionp = LUACURL_OPTIONP_UPVALUE(L, 1);
  struct curl_slist *headerlist = NULL;
  int i = 1;

  /* free previous slist for this option */
  l_easy_setopt_free_slist(privatep, *optionp);

  if (lua_isstring(L, 2))
    *l_easy_setopt_get_slist(privatep, *optionp) = curl_slist_append(headerlist, lua_tostring(L, 2));
  else {
    if (lua_type(L, 2) != LUA_TTABLE)
      luaL_error(L, "wrong argument (%s): expected string or table", lua_typename(L, 2));

    lua_rawgeti(L, 2, i++);
    while (!lua_isnil(L, -1)) {
      struct curl_slist *current_slist = *l_easy_setopt_get_slist(privatep, *optionp);
      struct curl_slist *new_slist = curl_slist_append(current_slist, lua_tostring(L, -1));
      *l_easy_setopt_get_slist(privatep, *optionp) = new_slist;
      lua_pop(L, 1);
      lua_rawgeti(L, 2, i++);
    }
    lua_pop(L, 1);
  }

  if (curl_easy_setopt(curl, *optionp, *l_easy_setopt_get_slist(privatep, *optionp)) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }
  /* memory leak: we need to free this in __gc */
  /*   curl_slist_free_all(headerlist);  */
  return 0;
}

static int l_easy_setopt_proxytype(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLoption *optionp = LUACURL_OPTIONP_UPVALUE(L, 1);
  const char *value = luaL_checkstring(L, 2);

  /* check for valid OPTION: */
  curl_proxytype type;

  if (!strcmp("HTTP", value))
    type = CURLPROXY_HTTP;
  else if (!strcmp("SOCKS4", value))
    type = CURLPROXY_SOCKS4;
  else if (!strcmp("SOCKS5", value))
    type = CURLPROXY_SOCKS5;
  else
    luaL_error(L, "Invalid proxytype: %s", value);

  if (curl_easy_setopt(curl, *optionp, type) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }
  return 0;
}

static int l_easy_setopt_share(lua_State *L) {
  l_easy_private *privatep = luaL_checkudata(L, 1, LUACURL_EASYMETATABLE);
  CURL *curl = privatep->curl;
  CURLoption *optionp = LUACURL_OPTIONP_UPVALUE(L, 1);
  CURLSH *curlsh = ((l_share_userdata*) luaL_checkudata(L, 2, LUACURL_SHAREMETATABLE))->curlsh;

  if (curl_easy_setopt(curl, CURLOPT_SHARE, curlsh) != CURLE_OK)
  {
    lua_pushnil(L);
    lua_pushfstring(L, "%s", privatep->error);
    return 2;
  }
  return 0;
}


/* closures assigned to setopt in setopt table */
static struct {
  const char *name;
  CURLoption option;
  lua_CFunction func;
} luacurl_setopt_c[] = {
  /* behavior options */
  {P"verbose", CURLOPT_VERBOSE, l_easy_setopt_long},
  {P"header", CURLOPT_HEADER, l_easy_setopt_long},
  {P"noprogrss", CURLOPT_NOPROGRESS, l_easy_setopt_long},
  {P"nosignal", CURLOPT_NOSIGNAL, l_easy_setopt_long},
  /* callback options */
  /* network options */
  /* names and passwords options  */
  /* http options */

  {P"autoreferer", CURLOPT_AUTOREFERER, l_easy_setopt_long},
  {P"encoding", CURLOPT_ENCODING, l_easy_setopt_string},
  {P"followlocation", CURLOPT_FOLLOWLOCATION, l_easy_setopt_long},
  {P"unrestricted_AUTH", CURLOPT_UNRESTRICTED_AUTH, l_easy_setopt_long},
  {P"maxredirs", CURLOPT_MAXREDIRS, l_easy_setopt_long},
  /* not implemented */
  /*   {P"put", CURLOPT_PUT, l_easy_setopt_long}, */
  {P"post", CURLOPT_POST, l_easy_setopt_long},
  {P"postfields", CURLOPT_POSTFIELDS, l_easy_setopt_string},
  {P"postfieldsize", CURLOPT_POSTFIELDSIZE, l_easy_setopt_long},
  {P"postfieldsize_LARGE", CURLOPT_POSTFIELDSIZE_LARGE, l_easy_setopt_long},
  {P"httppost", CURLOPT_HTTPPOST, l_easy_setopt_long},
  {P"referer", CURLOPT_REFERER, l_easy_setopt_string},
  {P"useragent", CURLOPT_USERAGENT, l_easy_setopt_string},
  {P"httpheader", CURLOPT_HTTPHEADER, l_easy_setopt_strings},
/*  Not implemented:  {P"http200aliases", CURLOPT_HTTP200ALIASES, l_easy_setopt_long}, */
  {P"cookie", CURLOPT_COOKIE, l_easy_setopt_string},
  {P"cookiefile", CURLOPT_COOKIEFILE, l_easy_setopt_string},
  {P"cookiejar", CURLOPT_COOKIEJAR, l_easy_setopt_string},
  {P"cookiesession", CURLOPT_COOKIESESSION, l_easy_setopt_long},
#ifdef CURLOPT_COOKIELIST
  {P"cookielist", CURLOPT_COOKIELIST, l_easy_setopt_string},
#endif
  {P"httpget", CURLOPT_HTTPGET, l_easy_setopt_long},
/*  Not implemented: {P"http_version", CURLOPT_HTTP_VERSION, l_easy_setopt_long}, */
  {P"ignore_content_length", CURLOPT_IGNORE_CONTENT_LENGTH, l_easy_setopt_long},
#ifdef CURLOPT_HTTP_CONTENT_DECODING
  {P"http_content_decoding", CURLOPT_HTTP_CONTENT_DECODING, l_easy_setopt_long},
#endif
#ifdef CURLOPT_HTTP_TRANSFER_DECODING
  {P"http_transfer_decoding ", CURLOPT_HTTP_TRANSFER_DECODING , l_easy_setopt_long},
#endif
  /* ftp options */
  /* protocol options */
  {P"transfertext", CURLOPT_TRANSFERTEXT, l_easy_setopt_long},
  {P"crlf", CURLOPT_CRLF, l_easy_setopt_long},
  {P"range", CURLOPT_RANGE, l_easy_setopt_string},
  {P"resume_from", CURLOPT_RESUME_FROM, l_easy_setopt_long},
  {P"resume_from_large", CURLOPT_RESUME_FROM_LARGE, l_easy_setopt_long},
  {P"customrequest", CURLOPT_CUSTOMREQUEST, l_easy_setopt_string},
  {P"filetime", CURLOPT_FILETIME, l_easy_setopt_long},
  {P"nobody", CURLOPT_NOBODY, l_easy_setopt_long},
  {P"infilesize", CURLOPT_INFILESIZE, l_easy_setopt_long},
  {P"infilesize_large", CURLOPT_INFILESIZE_LARGE, l_easy_setopt_long},
  {P"upload", CURLOPT_UPLOAD, l_easy_setopt_long},
  {P"maxfilesize", CURLOPT_MAXFILESIZE, l_easy_setopt_long},
  {P"maxfilesize_large", CURLOPT_MAXFILESIZE_LARGE, l_easy_setopt_long},
  {P"timecondition", CURLOPT_TIMECONDITION, l_easy_setopt_long},
  {P"timevalue ", CURLOPT_TIMEVALUE , l_easy_setopt_long},
  {P"quote", CURLOPT_QUOTE, l_easy_setopt_strings},
  {P"postquote", CURLOPT_POSTQUOTE, l_easy_setopt_strings},
  /* network options */
  {P"url", CURLOPT_URL, l_easy_setopt_string},
  {P"proxy", CURLOPT_PROXY, l_easy_setopt_string},
  {P"proxyport", CURLOPT_PROXYPORT, l_easy_setopt_long},
  {P"proxytype", CURLOPT_PROXYTYPE, l_easy_setopt_proxytype},
  {P"httpproxytunnel", CURLOPT_HTTPPROXYTUNNEL, l_easy_setopt_long},
  {P"interface", CURLOPT_INTERFACE, l_easy_setopt_string},
  {P"localport", CURLOPT_LOCALPORT, l_easy_setopt_long},
  {P"localportrange", CURLOPT_LOCALPORTRANGE, l_easy_setopt_long},
  {P"dns_cache_timeout", CURLOPT_DNS_CACHE_TIMEOUT, l_easy_setopt_long},
  {P"dns_use_global_cache", CURLOPT_DNS_USE_GLOBAL_CACHE, l_easy_setopt_long},
  {P"buffersize", CURLOPT_BUFFERSIZE, l_easy_setopt_long},
  {P"port", CURLOPT_PORT, l_easy_setopt_long},
  {P"TCP_nodelay", CURLOPT_TCP_NODELAY, l_easy_setopt_long},
  {P"ssl_verifypeer", CURLOPT_SSL_VERIFYPEER, l_easy_setopt_long},
  /* ssl options */
  {P"sslcert", CURLOPT_SSLCERT, l_easy_setopt_string},
  {P"sslcerttype", CURLOPT_SSLCERTTYPE, l_easy_setopt_string},
  {P"sslcertpasswd", CURLOPT_SSLCERTPASSWD, l_easy_setopt_string},
  {P"sslkey", CURLOPT_SSLKEY, l_easy_setopt_string},
  {P"sslkeytype", CURLOPT_SSLKEYTYPE, l_easy_setopt_string},
  {P"sslkeypasswd", CURLOPT_SSLKEYPASSWD, l_easy_setopt_string},
  {P"sslengine", CURLOPT_SSLENGINE, l_easy_setopt_string},
  {P"sslengine_default", CURLOPT_SSLENGINE_DEFAULT, l_easy_setopt_long},
  /* not implemented  {P"sslversion", CURLOPT_SSLVERSION, l_easy_setopt_string}, */
  {P"ssl_verifypeer", CURLOPT_SSL_VERIFYPEER, l_easy_setopt_long},
  {P"cainfo", CURLOPT_CAINFO, l_easy_setopt_string},
  {P"capath", CURLOPT_CAPATH, l_easy_setopt_string},
  {P"random_file", CURLOPT_RANDOM_FILE, l_easy_setopt_string},
  {P"egdsocket", CURLOPT_EGDSOCKET, l_easy_setopt_string},
  {P"ssl_verifyhost", CURLOPT_SSL_VERIFYHOST, l_easy_setopt_long},
  {P"ssl_cipher_list", CURLOPT_SSL_CIPHER_LIST, l_easy_setopt_string},
#ifdef CURLOPT_SSL_SESSIONID_CACHE
  {P"ssl_sessionid_cache", CURLOPT_SSL_SESSIONID_CACHE, l_easy_setopt_long},
#endif
  /* not implemented:   {P"krblevel", CURLOPT_KRBLEVEL, l_easy_setopt_string}, */
  /* other options */
  {P"share", CURLOPT_SHARE, l_easy_setopt_share},
  /* dummy opt value */
  {NULL, CURLOPT_VERBOSE, NULL}};

int l_easy_setopt_register(lua_State *L) {
  int i;

  /* register setopt closures */
  for (i=0; luacurl_setopt_c[i].name != NULL; i++) {
    CURLoption *optionp = &(luacurl_setopt_c[i].option);
    lua_pushlightuserdata(L, optionp);
    lua_pushcclosure(L, luacurl_setopt_c[i].func, 1);
    lua_setfield(L, -2, luacurl_setopt_c[i].name);
  }

  return 0;
}

void  l_easy_setopt_init_slists(lua_State *L, l_easy_private *privp) {
  int i, n;

  /* count required slists */
  for (i=0, n=0; luacurl_setopt_c[i].name != NULL; i++)
    if (luacurl_setopt_c[i].func == l_easy_setopt_strings) n++;

  privp->option_slists = (l_option_slist*) malloc(sizeof(l_option_slist) * ++n);
  if (privp->option_slists == NULL)
    luaL_error(L, "can't malloc option slists");

  /* Init slists */
  for (i=0, n=0; luacurl_setopt_c[i].name != NULL; i++) {
    CURLoption option = luacurl_setopt_c[i].option;
    if (luacurl_setopt_c[i].func == l_easy_setopt_strings) {
      privp->option_slists[n].option = option;
      privp->option_slists[n].slist = NULL;
      n++;
    }
  }
  /* term list */
  privp->option_slists[n].option = 0;
  privp->option_slists[n].slist = NULL;
}

void  l_easy_setopt_free_slists(l_easy_private *privp) {
  int i = 0;

  while (privp->option_slists[i].option != 0) {
    if (privp->option_slists[i].slist != NULL)
      curl_slist_free_all(privp->option_slists[i].slist);
    i++;
  }

  free(privp->option_slists);
}

#undef P

/*****************************************************************************/
/* Lua-cURL-share.c                                                          */
/*****************************************************************************/

#include <curl/curl.h>


//#include "Lua-cURL.h"
//#include "Lua-cURL-share.h"
//#include "Lua-utility.h"

static l_share_userdata* l_share_newuserdata(lua_State *L) {
  l_share_userdata *share_userdata = (l_share_userdata *) lua_newuserdata(L, sizeof(l_share_userdata));
  luaL_getmetatable(L, LUACURL_SHAREMETATABLE);
  lua_setmetatable(L, -2);
  return share_userdata;
}

int l_share_init(lua_State *L) {

  l_share_userdata *share_userdata = l_share_newuserdata(L);
  if ((share_userdata->curlsh = curl_share_init()) == NULL)
    luaL_error(L, "something went wrong and you cannot use the other curl functions");
  /* return userdata */
  return 1;
}

int l_share_setopt_share(lua_State *L) {
  l_share_userdata *privatep = luaL_checkudata(L, 1, LUACURL_SHAREMETATABLE);
  CURLSH *curlsh = privatep->curlsh;
  const char *value = luaL_checkstring(L, 2);
  CURLoption type;
  CURLSHcode  errornum;

  if (!strcmp("COOKIE", value))
    type = CURL_LOCK_DATA_COOKIE;
  else if (!strcmp("DNS", value))
    type = CURL_LOCK_DATA_DNS;
  else luaL_error(L, "Invalid share type: %s", value);

  if ((errornum = curl_share_setopt(curlsh, CURLSHOPT_SHARE, type)) != CURLSHE_OK)
    luaL_error(L, "%s", curl_share_strerror(errornum));
  return 0;
}

int l_share_gc(lua_State *L) {
  /* gc resources */
  l_share_userdata *privp = lua_touserdata(L, 1);
  CURLSH *curlsh = privp->curlsh;
  CURLSHcode  errornum;
  if ((errornum = curl_share_cleanup(curlsh)) != CURLSHE_OK)
    luaL_error(L, "%s", curl_share_strerror(errornum));

  return 0;
}

/*****************************************************************************/
/* Lua-utility.c                                                             */
/*****************************************************************************/

#include <stdio.h>

//#include "Lua-utility.h"

const char* luaL_getstrfield(lua_State* L, const char* key) {
  const char *val;
  lua_getfield(L, -1, key);
  val = lua_isnil(L, -1)? NULL : lua_tostring(L, -1);
  lua_pop(L, 1);
  return val;
}

const char* luaL_getlstrfield(lua_State* L, const char* key, int *len) {
  const char *val;
  lua_getfield(L, -1, key);
  val = lua_isnil(L, -1)? NULL : lua_tolstring(L, -1, (size_t*)len);
  lua_pop(L, 1);
  return val;
}

void _stackDump (lua_State *L, const char *file, int line) {
  int i;
  int top = lua_gettop(L);
  printf("%s:%d: Stackdump\n", file, line);
  for (i = 1; i <= top; i++) {  /* repeat for each level */
    int t = lua_type(L, i);
    printf("%d: ", i);
    switch (t) {
      case LUA_TSTRING:  /* strings */
        printf("`%s'\n", lua_tostring(L, i));
        break;

      case LUA_TBOOLEAN:  /* booleans */
        printf(lua_toboolean(L, i) ? "true" : "false");
        break;

      case LUA_TNUMBER:  /* numbers */
        printf("%g\n", lua_tonumber(L, i));
        break;

      default:  /* other values */
        printf("%s\n", lua_typename(L, t));
        break;

    }
    printf("  ");  /* put a separator */
  }
  printf("\n");  /* end the listing */
}
