/* BonaLuna

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 alpha
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
    char path[BL_PATHSIZE];
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
    char path[BL_PATHSIZE];
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
    char path[BL_PATHSIZE];
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

static int lz_adler(lua_State *L)
{
    lzo_uint32 adler;
    const lzo_bytep buf;
    lzo_uint len;
    if (lua_isnoneornil(L, 2))
    {
        adler = 0;
        buf = luaL_checkstring(L, 1);
        len = lua_rawlen(L, 1);
    }
    else
    {
        adler = luaL_checknumber(L, 1);
        buf = luaL_checkstring(L, 2);
        len = lua_rawlen(L, 2);
    }
    lua_pushunsigned(L, lzo_adler32(adler, buf, len));
    return 1;
}

#define LZO_SIG 0x004F5A4C
#define QLZ_SIG 0x005A4C51

typedef struct
{
    lzo_uint32  sig;
    lzo_uint32  len;
} t_lz_header;

#define HEAP_ALLOC(var,size) \
    lzo_align_t __LZO_MMODEL var [ ((size) + (sizeof(lzo_align_t) - 1)) / sizeof(lzo_align_t) ]

typedef enum { BEST, LZO, QLZ } t_lz_method;

static t_lz_method lz_method = BEST;

static int lz_lzo(lua_State *L)
{
    lz_method = LZO;
    return 0;
}

static int lz_qlz(lua_State *L)
{
    lz_method = QLZ;
    return 0;
}

static int lz_best(lua_State *L)
{
    lz_method = BEST;
    return 0;
}

void lz_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    lzo_uint lzo_dst_len;
    lzo_bytep lzo_dst;
    char *qlz_dst;
    size_t qlz_dst_len;
    if (lz_method == LZO || lz_method == BEST)
    {
        HEAP_ALLOC(wrkmem, LZO1X_1_MEM_COMPRESS);
        lzo_dst_len = src_len + src_len/16 + 64 + 3 + sizeof(t_lz_header);
        lzo_dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_1_compress(src, src_len, lzo_dst+sizeof(t_lz_header), &lzo_dst_len, wrkmem);
        if (r != LZO_E_OK) luaL_error(L, "lz: lzo1x_1_compress failed (error: %d)", r);
        ((t_lz_header*)lzo_dst)->sig = LZO_SIG;
        ((t_lz_header*)lzo_dst)->len = src_len;
        *dst = lzo_dst;
        *dst_len = lzo_dst_len;
    }
    if (lz_method == QLZ || lz_method == BEST)
    {
        qlz_state_compress *state_compress = (qlz_state_compress *)malloc(sizeof(qlz_state_compress));
        qlz_dst = (char*)malloc(src_len + 400 + sizeof(t_lz_header));
        qlz_dst_len = qlz_compress(src, qlz_dst+sizeof(t_lz_header), src_len, state_compress);
        free(state_compress);
        ((t_lz_header*)qlz_dst)->sig = QLZ_SIG;
        ((t_lz_header*)qlz_dst)->len = src_len;
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
    }
    *dst_len += sizeof(t_lz_header);
}

int lz_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_lz_header*)src)->sig == LZO_SIG)
    {
        lzo_uint lzo_dst_len = ((t_lz_header*)src)->len;
        *dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_decompress_safe(src+sizeof(t_lz_header), src_len-sizeof(t_lz_header), *dst, &lzo_dst_len, NULL);
        if (r != LZO_E_OK) luaL_error(L, "lz: lzo1x_decompress failed (error: %d)", r);
        *dst_len = lzo_dst_len;
        return 1;
    }
    if (((t_lz_header*)src)->sig == QLZ_SIG)
    {
        qlz_state_decompress *state_decompress = (qlz_state_decompress *)malloc(sizeof(qlz_state_decompress));
        *dst_len = ((t_lz_header*)src)->len;
        *dst = (char*)malloc(*dst_len);
        *dst_len = qlz_decompress(src+sizeof(t_lz_header), *dst, state_decompress);
        free(state_decompress);
        return 1;
    }
    return 0;
}
        
static int lz_compress(lua_State *L)
{
    const char *src = luaL_checkstring(L, 1);
    size_t src_len = lua_rawlen(L, 1);
    char *dst;
    size_t dst_len;
    lz_compress_core(L, src, src_len, &dst, &dst_len);
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
    if (lz_decompress_core(L, src, src_len, &dst, &dst_len))
    {
        lua_pop(L, 1);
        lua_pushlstring(L, dst, (size_t)(dst_len));
        free(dst);
        return 1;
    }
    else
    {
        lua_pop(L, 1);
        lua_pushnil(L);
        lua_pushstring(L, "lz: not a compressed string");
        return 2;
    }
}

static const luaL_Reg lzlib[] =
{
    {"adler", lz_adler},
    {"lzo", lz_lzo},
    {"qlz", lz_qlz},
    {"best", lz_best},
    {"compress", lz_compress},
    {"decompress", lz_decompress},
    {NULL, NULL}
};

LUAMOD_API int luaopen_lz (lua_State *L)
{
    if (lzo_init() != LZO_E_OK)
    {
        luaL_error(L, "lz: lzo_init() failed !!!");
    }
    luaL_newlib(L, lzlib);
    return 1;
}

