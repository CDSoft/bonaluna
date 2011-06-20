/* BonaLuna

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

#include "bonaluna.h"

#include "dirent.h"
#include "errno.h"
#include "sys/stat.h"
#include "unistd.h"
#include "utime.h"
//#include <string.h>
//#include <stdlib.h>
//#include <stdio.h>
//#include <time.h>
#include <stdint.h>

#ifdef __MINGW32__
//#include <winsock2.h>
#include <windows.h>
#else
#include "glob.h"
//#include <sys/types.h>
//#include <sys/socket.h>
//#include <netinet/in.h>
//#include <arpa/inet.h>
//#include <sys/time.h>
//#include <unistd.h>
//#include <signal.h>
//#include <fcntl.h>
//#include <netdb.h>
//#include <errno.h>
//#include <endian.h>
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

static int bl_pusherror1(lua_State *L, const char *msg, const char *arg1)
{
    lua_pushnil(L);
    lua_pushfstring(L, msg, arg1);
    return 2;
}

static int bl_pusherror2(lua_State *L, const char *msg, const char *arg1, int arg2)
{
    lua_pushnil(L);
    lua_pushfstring(L, msg, arg1, arg2);
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
    int n = 0;
    if (dir)
    {
        lua_newtable(L); /* file list */
        while (file = readdir(dir))
        {
            if (strcmp(file->d_name, ".")==0) continue;
            if (strcmp(file->d_name, "..")==0) continue;
            lua_pushstring(L, file->d_name);
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

#ifdef __MINGW32__

/* no glob function */
/* TODO: implement glob in Lua (bl.lua may contain standard BonaLuna libraries) */

#else

static int fs_glob(lua_State *L)
{
    const char *pattern;
    if (lua_isstring(L, 1))
    {
        pattern = luaL_checkstring(L, 1);
    }
    else if (lua_isnoneornil(L, 1))
    {
        pattern = "*";
    }
    else
    {
        return bl_pusherror(L, "bad argument #1 to pattern (none, nil or string expected)");
    }
    glob_t globres;
    unsigned int i;
    int r = glob(pattern, GLOB_BRACE, NULL, &globres);
    if (r == 0 || r == GLOB_NOMATCH)
    {
        lua_newtable(L); /* file list */
        for (i=1; i<=globres.gl_pathc; i++)
        {
            lua_pushstring(L, globres.gl_pathv[i-1]);
            lua_rawseti(L, -2, i);
        }
        globfree(&globres);
        return 1;
    }
    else
    {
        return bl_pushresult(L, 0, pattern);
    }
}

#endif

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
#define INTEGER(VAL, ATTR) lua_pushunsigned(L, VAL); lua_setfield(L, -2, ATTR)
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
        INTEGER(buf.st_dev, "dev");
        INTEGER(buf.st_ino, "ino");
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

static int fs_basename(lua_State *L)
{
    char path[BL_PATHSIZE+1];
    strncpy(path, luaL_checkstring(L, 1), BL_PATHSIZE);
    path[BL_PATHSIZE] = '\0';
    char *p = path;
    while (*p) p++;
    while (p>path && (*(p-1)=='/' || *(p-1)=='\\')) *--p = '\0';
    while (p>path && (*(p-1)!='/' && *(p-1)!='\\')) p--;
    lua_pushstring(L, p);
    return 1;
}

static int fs_dirname(lua_State *L)
{
    char path[BL_PATHSIZE+1];
    strncpy(path, luaL_checkstring(L, 1), BL_PATHSIZE);
    path[BL_PATHSIZE] = '\0';
    char *p = path;
    while (*p) p++;
    while (p>path && (*(p-1)=='/' || *(p-1)=='\\')) *--p = '\0';
    while (p>path && (*(p-1)!='/' && *(p-1)!='\\')) *--p = '\0';
    while (p>path && (*(p-1)=='/' || *(p-1)=='\\')) *--p = '\0';
    lua_pushstring(L, path);
    return 1;
}

static int fs_absname(lua_State *L)
{
    char path[BL_PATHSIZE+1];
    const char *name = luaL_checkstring(L, 1);
    if (  name[0] == '/' || name[0] == '\\'
       || name[0] && name[1] == ':'
       )
    {
        /* already an absolute path */
        lua_pushstring(L, name);
        return 1;
    }
    getcwd(path, BL_PATHSIZE);
    strncat(path, LUA_DIRSEP, BL_PATHSIZE-strlen(path));
    strncat(path, name, BL_PATHSIZE-strlen(path));
    lua_pushstring(L, path);
    return 1;
}

static const luaL_Reg fslib[] =
{
    {"basename",    fs_basename},
    {"dirname",     fs_dirname},
    {"absname",     fs_absname},
    {"getcwd",      fs_getcwd},
    {"chdir",       fs_chdir},
    {"dir",         fs_dir},
#ifdef __MINGW32__
    /* no glob function */
#else
    {"glob",        fs_glob},
#endif
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
#define INTEGER(NAME, VAL) lua_pushunsigned(L, VAL); lua_setfield(L, -2, NAME)
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
#undef INTEGER
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
    lua_pushunsigned(L, gethostid());
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

/*******************************************************************/
/* lz: compression library                                         */
/*******************************************************************/

#ifdef USE_LZ

#define LZO_SIG  0x004F5A4C
#define QLZ_SIG  0x005A4C51
#define LZ4_SIG  0x00345A4C

typedef struct
{
    uint32_t  sig;
    uint32_t  len;
} t_lz_header;

typedef enum { BEST, LZO, QLZ, LZ4 } t_lz_method;

#ifdef USE_LZ_TWO_OR_MORE
static t_lz_method lz_method = BEST;
#endif

#ifdef USE_LZO_AND_MORE
static int lz_lzo(lua_State *L)
{
    lz_method = LZO;
    return 0;
}
#endif

#ifdef USE_QLZ_AND_MORE
static int lz_qlz(lua_State *L)
{
    lz_method = QLZ;
    return 0;
}
#endif

#ifdef USE_LZ4_AND_MORE
static int lz_lz4(lua_State *L)
{
    lz_method = LZ4;
    return 0;
}
#endif

#ifdef USE_ZLIB_AND_MORE
static int lz_zlib(lua_State *L)
{
    lz_method = ZLIB;
    return 0;
}
#endif

#ifdef USE_LZ_TWO_OR_MORE
static int lz_best(lua_State *L)
{
    lz_method = BEST;
    return 0;
}
#endif

int lz_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
#ifdef USE_LZO
#ifdef USE_LZO_AND_MORE
    if (lz_method == LZO || lz_method == BEST)
    {
#endif
#define HEAP_ALLOC(var,size) \
    lzo_align_t __LZO_MMODEL var [ ((size) + (sizeof(lzo_align_t) - 1)) / sizeof(lzo_align_t) ]
        HEAP_ALLOC(wrkmem, LZO1X_1_MEM_COMPRESS);
        lzo_uint lzo_dst_len = src_len + src_len/16 + 64 + 3 + sizeof(t_lz_header);
        lzo_bytep lzo_dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_1_compress(src, src_len, lzo_dst+sizeof(t_lz_header), &lzo_dst_len, wrkmem);
        if (r != LZO_E_OK)
        {
            lua_pushnil(L);
            lua_pushfstring(L, "lz: lzo1x_1_compress failed (error: %d)", r);
            return 2;
        }
        ((t_lz_header*)lzo_dst)->sig = LZO_SIG;
        ((t_lz_header*)lzo_dst)->len = src_len;
        *dst = lzo_dst;
        *dst_len = lzo_dst_len;
#ifdef USE_LZO_AND_MORE
    }
#endif
#endif
#ifdef USE_QLZ
#ifdef USE_QLZ_AND_MORE
    if (lz_method == QLZ || lz_method == BEST)
    {
#endif
        qlz_state_compress *state_compress = (qlz_state_compress *)malloc(sizeof(qlz_state_compress));
        char *qlz_dst = (char*)malloc(src_len + 400 + sizeof(t_lz_header));
        size_t qlz_dst_len = qlz_compress(src, qlz_dst+sizeof(t_lz_header), src_len, state_compress);
        free(state_compress);
        ((t_lz_header*)qlz_dst)->sig = QLZ_SIG;
        ((t_lz_header*)qlz_dst)->len = src_len;
#ifdef USE_QLZ_FIRST
        *dst = qlz_dst;
        *dst_len = qlz_dst_len;
#else
        if (lz_method == QLZ)
        {
            *dst = qlz_dst;
            *dst_len = qlz_dst_len;
        }
        else if (lz_method == BEST)
        {
            if (qlz_dst_len < *dst_len)
            {
                free(*dst);
                *dst = qlz_dst;
                *dst_len = qlz_dst_len;
            }
            else
            {
                free(qlz_dst);
            }
        }
#endif
#ifdef USE_QLZ_AND_MORE
    }
#endif
#endif
#ifdef USE_LZ4
#ifdef USE_LZ4_AND_MORE
    if (lz_method == LZ4 || lz_method == BEST)
    {
#endif
        char *lz4_dst = (char*)malloc(src_len + src_len/2 + 8 + sizeof(t_lz_header));
        int lz4_dst_len = LZ4_compress((char*)src, lz4_dst+sizeof(t_lz_header), src_len);
        ((t_lz_header*)lz4_dst)->sig = LZ4_SIG;
        ((t_lz_header*)lz4_dst)->len = src_len;
#ifdef USE_LZ4_FIRST
        *dst = lz4_dst;
        *dst_len = lz4_dst_len;
#else
        if (lz_method == LZ4)
        {
            *dst = lz4_dst;
            *dst_len = lz4_dst_len;
        }
        else if (lz_method == BEST)
        {
            if (lz4_dst_len < *dst_len)
            {
                free(*dst);
                *dst = lz4_dst;
                *dst_len = lz4_dst_len;
            }
            else
            {
                free(lz4_dst);
            }
        }
#endif
#ifdef USE_LZ4_AND_MORE
    }
#endif
#endif
    *dst_len += sizeof(t_lz_header);
    return 0;
}

int lz_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
#ifdef USE_LZO
    if (((t_lz_header*)src)->sig == LZO_SIG)
    {
        lzo_uint lzo_dst_len = ((t_lz_header*)src)->len;
        *dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_decompress_safe(src+sizeof(t_lz_header), src_len-sizeof(t_lz_header), *dst, &lzo_dst_len, NULL);
        if (r != LZO_E_OK)
        {
            lua_pushnil(L);
            lua_pushfstring(L, "lz: lzo1x_decompress failed (error: %d)", r);
            return 2;
        }
        *dst_len = lzo_dst_len;
        return 0;
    }
#endif
#ifdef USE_QLZ
    if (((t_lz_header*)src)->sig == QLZ_SIG)
    {
        qlz_state_decompress *state_decompress = (qlz_state_decompress *)malloc(sizeof(qlz_state_decompress));
        *dst_len = ((t_lz_header*)src)->len;
        *dst = (char*)malloc(*dst_len);
        *dst_len = qlz_decompress(src+sizeof(t_lz_header), *dst, state_decompress);
        free(state_decompress);
        return 0;
    }
#endif
#ifdef USE_LZ4
    if (((t_lz_header*)src)->sig == LZ4_SIG)
    {
        *dst = (char*)malloc(((t_z_header*)src)->len + 3);
        *dst_len = LZ4_decode((char*)(src+sizeof(t_lz_header)), *dst, src_len-sizeof(t_lz_header));
        return 0;
    }
#endif
    lua_pushnil(L);
    lua_pushstring(L, "lz: not a compressed string");
    return 2;
}
        
static int lz_compress(lua_State *L)
{
    const char *src = luaL_checkstring(L, 1);
    size_t src_len = lua_rawlen(L, 1);
    char *dst;
    size_t dst_len;
    int n = lz_compress_core(L, src, src_len, &dst, &dst_len);
    if (n > 0) return n; /* error messages pushed by lz_compress_core */
    lua_pop(L, 1);
    lua_pushlstring(L, dst, (size_t)(dst_len));
    free(dst);
    return 1;
}

static int lz_decompress(lua_State *L)
{
    const char *src = luaL_checkstring(L, 1);
    size_t src_len = lua_rawlen(L, 1);
    char *dst;
    size_t dst_len;
    int n = lz_decompress_core(L, src, src_len, &dst, &dst_len);
    if (n > 0) return n; /* error messages pushed by lz_decompress_core */
    lua_pop(L, 1);
    lua_pushlstring(L, dst, (size_t)(dst_len));
    free(dst);
    return 1;
}

static const luaL_Reg lzlib[] =
{
#ifdef USE_LZO_AND_MORE
    {"lzo", lz_lzo},
#endif
#ifdef USE_QLZ_AND_MORE
    {"qlz", lz_qlz},
#endif
#ifdef USE_LZ4_AND_MORE
    {"lz4", lz_lz4},
#endif
#ifdef USE_Z_TWO_OR_MORE
    {"best", lz_best},
#endif
    {"compress", lz_compress},
    {"decompress", lz_decompress},
    {NULL, NULL}
};

LUAMOD_API int luaopen_lz (lua_State *L)
{
#ifdef USE_LZO
    if (lzo_init() != LZO_E_OK)
    {
        luaL_error(L, "lz: lzo_init() failed !!!");
    }
#endif
    luaL_newlib(L, lzlib);
    return 1;
}

#endif

