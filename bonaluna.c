/* BonaLuna

Copyright (C) 2010 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 work 5
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

#include "bonaluna.h"

#include "dirent.h"
#include "errno.h"
#include "sys/stat.h"
#include "unistd.h"
#include "utime.h"

#ifdef __MINGW32__
#include "windows.h"
#endif

#define BL_PATHSIZE 1024
#define BL_BUFSIZE  (64*1024)

static int bl_pushresult(lua_State *L, int i, const char *filename)
{
    int en = errno;  /* calls to Lua API may change this value */
    if (i)
    {
        lua_pushboolean(L, 1);
        return 1;
    }
    else
    {
        lua_pushnil(L);
        lua_pushfstring(L, "%s: %s", filename, strerror(en));
        lua_pushinteger(L, en);
        return 3;
    }
}

static int bl_pusherror(lua_State *L, const char *msg)
{
    lua_pushnil(L);
    lua_pushstring(L, msg);
    return 2;
}

/*******************************************************************/
/* fs: File System                                                 */
/*******************************************************************/

static int fs_getcwd(lua_State *L)
{
    char path[BL_PATHSIZE+1];
    lua_pushstring(L, getcwd(path, BL_PATHSIZE));
    return 1;
}

static int fs_chdir(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    return bl_pushresult(L, chdir(path) == 0, path);
}

static int fs_dir(lua_State *L)
{
    const char *path;
    if (lua_isstring(L, 1))
    {
        path = luaL_checkstring(L, 1);
    }
    else if (lua_isnoneornil(L, 1))
    {
        path = ".";
    }
    else
    {
        return bl_pusherror(L, "bad argument #1 to dir (none, nil or string expected)");
    }
    DIR *dir = opendir(path);
    struct dirent *file;
    char fullpath[BL_PATHSIZE+1] = "";
    char *fullpathend = fullpath;
    int fullpathlen = strlen(path);
    struct stat buf;
    if (fullpathlen > 0)
    {
        strncpy(fullpath, path, BL_PATHSIZE);
        fullpathend += fullpathlen;
        if (*(fullpathend-1) != '\\' && *(fullpathend-1) != '/')
        {
            strncpy(fullpathend, LUA_DIRSEP, BL_PATHSIZE-fullpathlen);
            fullpathend++;
            fullpathlen++;
        }
    }
    //printf("fullpath = %s %d\n", fullpath, fullpathend-fullpath);
    int n = 0;
    if (dir)
    {
        lua_newtable(L); /* file list */
        while (file = readdir(dir))
        {
            if (strcmp(file->d_name, ".")==0) continue;
            if (strcmp(file->d_name, "..")==0) continue;
            lua_newtable(L); /* file info (name, path, type) */
            lua_pushstring(L, file->d_name); lua_setfield(L, -2, "name");
            strncpy(fullpathend, file->d_name, BL_PATHSIZE-fullpathlen);
            lua_pushstring(L, fullpath); lua_setfield(L, -2, "path");
#ifdef __MINGW32__
            stat(fullpath, &buf);
            //printf("%s %s %d\n", file->d_name, fullpath, S_ISDIR(buf.st_mode));
            lua_pushstring(L, S_ISDIR(buf.st_mode)?"directory":S_ISREG(buf.st_mode)?"file":"unknown");
#else
            lua_pushstring(L, file->d_type==DT_DIR?"directory":file->d_type==DT_REG?"file":"unknown");
#endif
            lua_setfield(L, -2, "type");
            lua_rawseti(L, -2, ++n);
        }
        closedir(dir);
        return 1;
    }
    else
    {
        return bl_pushresult(L, 0, path);
    }
}

static int fs_remove(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
#ifdef __MINGW32__
    struct stat st;
    stat(filename, &st);
    if (S_ISDIR(st.st_mode))
    {
        return bl_pushresult(L, rmdir(filename) == 0, filename);
    }
#endif
    return bl_pushresult(L, remove(filename) == 0, filename);
}

static int fs_rename(lua_State *L)
{
    const char *fromname = luaL_checkstring(L, 1);
    const char *toname = luaL_checkstring(L, 2);
    return bl_pushresult(L, rename(fromname, toname) == 0, fromname);
}

static int fs_copy(lua_State *L)
{
    const char *fromname = luaL_checkstring(L, 1);
    const char *toname = luaL_checkstring(L, 2);
    int _en;
    FILE *from, *to;
    int n;
    char buffer[BL_BUFSIZE];
    struct stat st;
    struct utimbuf t;
    from = fopen(fromname, "rb");
    if (!from) return bl_pushresult(L, 0, fromname);
    to = fopen(toname, "wb");
    if (!to)
    {
        _en = errno;
        fclose(from);
        errno = _en;
        return bl_pushresult(L, 0, toname);
    }
    while (n = fread(buffer, sizeof(char), BL_BUFSIZE, from))
    {
        if (fwrite(buffer, sizeof(char), n, to) != n)
        {
            _en = errno;
            fclose(from);
            fclose(to);
            remove(toname);
            errno = _en;
            return bl_pushresult(L, 0, toname);
        }
    }
    if (ferror(from))
    {
        _en = errno;
        fclose(from);
        fclose(to);
        remove(toname);
        errno = _en;
        return bl_pushresult(L, 0, toname);
    }
    fclose(from);
    fclose(to);
    if (stat(fromname, &st) != 0) return bl_pushresult(L, 0, fromname);
    t.actime = st.st_atime;
    t.modtime = st.st_mtime;
    return bl_pushresult(L, 
        utime(toname, &t) == 0 && chmod(toname, st.st_mode) == 0,
        toname);
}

static int fs_mkdir(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
#ifdef __MINGW32__
    return bl_pushresult(L, mkdir(path) == 0, path);
#else
    return bl_pushresult(L, mkdir(path, 0755) == 0, path);
#endif
}

static int fs_stat(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    struct stat buf;
    if (stat(path, &buf)==0)
    {
#define STRING(VAL, ATTR) lua_pushstring(L, VAL); lua_setfield(L, -2, ATTR)
#define INTEGER(VAL, ATTR) lua_pushinteger(L, VAL); lua_setfield(L, -2, ATTR)
        lua_newtable(L); /* stat */
        STRING(path, "name");
        INTEGER(buf.st_size, "size");
        INTEGER(buf.st_mtime, "mtime");
        INTEGER(buf.st_atime, "atime");
        INTEGER(buf.st_ctime, "ctime");
        STRING(S_ISDIR(buf.st_mode)?"directory":S_ISREG(buf.st_mode)?"file":"unknown", "type");
        INTEGER(buf.st_mode, "mode");
#define PERMISSION(MASK, ATTR) lua_pushboolean(L, buf.st_mode & MASK); lua_setfield(L, -2, ATTR);
        PERMISSION(S_IRUSR, "uR");
        PERMISSION(S_IWUSR, "uW");
        PERMISSION(S_IEXEC, "uX");
#ifndef __MINGW32__
        PERMISSION(S_IRGRP, "gR");
        PERMISSION(S_IWGRP, "gW");
        PERMISSION(S_IXGRP, "gX");
        PERMISSION(S_IROTH, "oR");
        PERMISSION(S_IWOTH, "oW");
        PERMISSION(S_IXOTH, "oX");
#endif
#undef STRING
#undef INTEGER
#undef PERMISSION
        return 1;
    }
    else
    {
        return bl_pushresult(L, 0, path);
    }
}

static int fs_chmod(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    mode_t mode;
    if (lua_type(L, 2) == LUA_TNUMBER)
    {
        mode = 0;
        for (int i=2; !lua_isnone(L, i); i++)
        {
            mode |= (mode_t)luaL_checknumber(L, i);
        }
    }
    else if (lua_type(L, 2) == LUA_TSTRING)
    {
        const char *ref = luaL_checkstring(L, 2);
        struct stat st;
        if (stat(ref, &st) != 0) return bl_pushresult(L, 0, ref);
        mode = st.st_mode;
    }
    else
    {
        return bl_pusherror(L, "bad argument #2 to 'chmod' (number or string expected)");
    }
    return bl_pushresult(L, chmod(path, mode) == 0, path);
}

static int fs_touch(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    struct utimbuf t;
    if (lua_isnoneornil(L, 2))
    {
        t.actime = t.modtime = time(NULL);
    }
    else if (lua_type(L, 2) == LUA_TNUMBER)
    {
        t.actime = t.modtime = luaL_checknumber(L, 2);
    }
    else if (lua_type(L, 2) == LUA_TSTRING)
    {
        const char *ref = luaL_checkstring(L, 2);
        struct stat st;
        if (stat(ref, &st) != 0) return bl_pushresult(L, 0, ref);
        t.actime = st.st_atime;
        t.modtime = st.st_mtime;
    }
    else
    {
        return bl_pusherror(L, "bad argument #2 to touch (none, nil, number or string expected)");
    }
    return bl_pushresult(L, utime(path, &t) == 0, path);
}

static const luaL_Reg fslib[] =
{
    {"getcwd",      fs_getcwd},
    {"chdir",       fs_chdir},
    {"dir",         fs_dir},
    {"remove",      fs_remove},
    {"rename",      fs_rename},
    {"mkdir",       fs_mkdir},
    {"stat",        fs_stat},
    {"chmod",       fs_chmod},
    {"touch",       fs_touch},
    {"copy",        fs_copy},
    {NULL, NULL}
};

LUAMOD_API int luaopen_fs (lua_State *L)
{
    //luaL_register(L, LUA_FSLIBNAME, fslib);
    luaL_newlib(L, fslib);
#define STRING(NAME, VAL) lua_pushliteral(L, VAL); lua_setfield(L, -2, NAME)
#define INTEGER(NAME, VAL) lua_pushinteger(L, VAL); lua_setfield(L, -2, NAME)
    /* File separator */
    STRING("sep", LUA_DIRSEP);
    /* File permission bits */
    INTEGER("uR", S_IRUSR);
    INTEGER("uW", S_IWUSR);
    INTEGER("uX", S_IEXEC);
#ifdef __MINGW32__
    INTEGER("aR", S_IRUSR);
    INTEGER("aW", S_IWUSR);
    INTEGER("aX", S_IEXEC);
#else
    INTEGER("aR", S_IRUSR|S_IRGRP|S_IROTH);
    INTEGER("aW", S_IWUSR|S_IWGRP|S_IWOTH);
    INTEGER("aX", S_IEXEC|S_IXGRP|S_IXOTH);
    INTEGER("gR", S_IRGRP);
    INTEGER("gW", S_IWGRP);
    INTEGER("gX", S_IXGRP);
    INTEGER("oR", S_IROTH);
    INTEGER("oW", S_IWOTH);
    INTEGER("oX", S_IXOTH);
#endif
#undef STRING
    return 1;
}

/*******************************************************************/
/* ps: Processes                                                   */
/*******************************************************************/

static int ps_sleep(lua_State *L)
{
    double t = luaL_checknumber(L, 1);
#ifdef __MINGW32__
    Sleep(1000 * t);
#else
    struct timeval timeout;
    long int s = t;
    long int us = 1e6*(t-s);
    timeout.tv_sec = s;
    timeout.tv_usec = us;
    select(0, NULL, NULL, NULL, &timeout);
#endif
    return 0;
}

static const luaL_Reg pslib[] =
{
    {"sleep",       ps_sleep},
    {NULL, NULL}
};

LUAMOD_API int luaopen_ps (lua_State *L)
{
    //luaL_register(L, LUA_PSLIBNAME, pslib);
    luaL_newlib(L, pslib);
    return 1;
}

/*******************************************************************/
/* sys: System management                                          */
/*******************************************************************/

static int sys_hostname(lua_State *L)
{
    char name[BL_PATHSIZE+1];
    if (gethostname(name, BL_PATHSIZE)==0)
    {
        lua_pushstring(L, name);
    }
    else
    {
        return bl_pushresult(L, 0, "");
    }
    lua_pushstring(L, name);
    return 1;
}

static int sys_domainname(lua_State *L)
{
#ifdef __MINGW32__
    return bl_pusherror(L, "getdomainname not defined by mingw");
#else
    char name[BL_PATHSIZE+1];
    if (getdomainname(name, BL_PATHSIZE)==0)
    {
        lua_pushstring(L, name);
    }
    else
    {
        return bl_pushresult(L, 0, "");
    }
    return 1;
#endif
}

static int sys_hostid(lua_State *L)
{
#ifdef __MINGW32__
    return bl_pusherror(L, "gethostid not defined by mingw");
#else
    lua_pushinteger(L, gethostid());
    return 1;
#endif
}

static const luaL_Reg blsyslib[] =
{
    {"hostname",    sys_hostname},
    {"domainname",  sys_domainname},
    {"hostid",      sys_hostid},
    {NULL, NULL}
};

LUAMOD_API int luaopen_sys (lua_State *L)
{
    //luaL_register(L, LUA_SYSLIBNAME, blsyslib);
    luaL_newlib(L, blsyslib);
#define STRING(NAME, VAL) lua_pushliteral(L, VAL); lua_setfield(L, -2, NAME)
    STRING("platform", BONALUNA_PLATFORM);
#undef STRING
    return 1;
}

