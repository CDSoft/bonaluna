/* BonaLuna

Copyright (C) 2010-2015 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2015 Lua.org, PUC-Rio

Freely available under the terms of the Lua license.
*/

#include "bonaluna.h"

#include "dirent.h"
#include "errno.h"
#include "sys/types.h"
#include "sys/stat.h"
#include "unistd.h"
#include "utime.h"
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>

#ifdef __MINGW32__
#include <io.h>
#include <windows.h>
#include <wincrypt.h>
#include <ws2tcpip.h>
#else
#include "glob.h"
#include "sys/select.h"
#endif

#ifdef USE_ZLIB
#include "zlib.h"
#endif

#ifdef USE_UCL
#include "ucl.h"
#endif

#ifdef USE_LZ4
#include "lz4.h"
#include "lz4hc.h"
#endif

#ifdef USE_LZO
#include "lzo1x.h"
#endif

#ifdef USE_LZMA
#include "lzma.h"
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
/* TODO: implement glob in Lua */

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
        PERMISSION(S_IXUSR, "uX");
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

#ifdef __MINGW32__

/* "inode" number for MS-Windows (http://gnuwin32.sourceforge.net/compile.html) */

static ino_t getino(const char *path)
{
    #define LODWORD(l) ((DWORD)((DWORDLONG)(l)))
    #define HIDWORD(l) ((DWORD)(((DWORDLONG)(l)>>32)&0xFFFFFFFF))
    #define MAKEDWORDLONG(a,b) ((DWORDLONG)(((DWORD)(a))|(((DWORDLONG)((DWORD)(b)))<<32)))
    #define INOSIZE (8*sizeof(ino_t))
    #define SEQNUMSIZE (16)

    BY_HANDLE_FILE_INFORMATION FileInformation;
    HANDLE hFile;
    uint64_t ino64, refnum;
    ino_t ino;
    if (!path || !*path) /* path = NULL */
        return 0;
    if (access(path, F_OK)) /* path does not exist */
        return -1;
    /* obtain handle to "path"; FILE_FLAG_BACKUP_SEMANTICS is used to open directories */
    hFile = CreateFile(path, 0, 0, NULL, OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_ATTRIBUTE_READONLY,
            NULL);
    if (hFile == INVALID_HANDLE_VALUE) /* file cannot be opened */
        return 0;
    ZeroMemory(&FileInformation, sizeof(FileInformation));
    if (!GetFileInformationByHandle(hFile, &FileInformation)) { /* cannot obtain FileInformation */
        CloseHandle(hFile);
        return 0;
    }
    ino64 = (uint64_t)MAKEDWORDLONG(
        FileInformation.nFileIndexLow, FileInformation.nFileIndexHigh);
    refnum = ino64 & ((~(0ULL)) >> SEQNUMSIZE); /* strip sequence number */
    /* transform 64-bits ino into 16-bits by hashing */
    ino = (ino_t)(
            ( (LODWORD(refnum)) ^ ((LODWORD(refnum)) >> INOSIZE) )
        ^
            ( (HIDWORD(refnum)) ^ ((HIDWORD(refnum)) >> INOSIZE) )
        );
    CloseHandle(hFile);
    return ino;

    #undef LODWORD
    #undef HIDWORD
    #undef MAKEDWORDLONG
    #undef INOSIZE
    #undef SEQNUMSIZE
}
#endif

static int fs_inode(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    struct stat buf;
    if (stat(path, &buf)==0)
    {
#define INTEGER(VAL, ATTR) lua_pushinteger(L, VAL); lua_setfield(L, -2, ATTR)
        lua_newtable(L); /* stat */
        INTEGER(buf.st_dev, "dev");
#ifdef __MINGW32__
        INTEGER(getino(path), "ino");
#else
        INTEGER(buf.st_ino, "ino");
#endif
#undef INTEGER
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
    {"listdir",     fs_dir},
#ifdef __MINGW32__
    /* no glob function */
#else
    {"glob",        fs_glob},
#endif
    {"remove",      fs_remove},
    {"rename",      fs_rename},
    {"mkdir",       fs_mkdir},
    {"stat",        fs_stat},
    {"inode",       fs_inode},
    {"chmod",       fs_chmod},
    {"touch",       fs_touch},
    {"copy",        fs_copy},
    {NULL, NULL}
};

LUAMOD_API int luaopen_fs (lua_State *L)
{
    luaL_newlib(L, fslib);
#define STRING(NAME, VAL) lua_pushliteral(L, VAL); lua_setfield(L, -2, NAME)
#define INTEGER(NAME, VAL) lua_pushinteger(L, VAL); lua_setfield(L, -2, NAME)
    /* File separator */
    STRING("sep", LUA_DIRSEP);
    /* File permission bits */
    INTEGER("uR", S_IRUSR);
    INTEGER("uW", S_IWUSR);
    INTEGER("uX", S_IXUSR);
#ifdef __MINGW32__
    INTEGER("aR", S_IRUSR);
    INTEGER("aW", S_IWUSR);
    INTEGER("aX", S_IXUSR);
#else
    INTEGER("aR", S_IRUSR|S_IRGRP|S_IROTH);
    INTEGER("aW", S_IWUSR|S_IWGRP|S_IWOTH);
    INTEGER("aX", S_IXUSR|S_IXGRP|S_IXOTH);
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
    luaL_newlib(L, blsyslib);
#define STRING(NAME, VAL) lua_pushliteral(L, VAL); lua_setfield(L, -2, NAME)
    STRING("platform", BONALUNA_PLATFORM);
#undef STRING
    return 1;
}

/*******************************************************************/
/* z, minilzo, lzo, qlz, lz4, zlib, ucl, lzma: compression libraries */
/*******************************************************************/

#ifdef USE_Z

#define LZO_SIG  0x004F5A4C
#define UCL_SIG  0x004C4355
#define QLZ_SIG  0x005A4C51
#define LZ4_SIG  0x00345A4C
#define LZF_SIG  0x00465A4C
#define ZLIB_SIG 0x42494C5A
#define LZMA_SIG 0x414D5A4C

typedef struct
{
    uint32_t  sig;
    uint32_t  len;
} t_z_header;

#define COMPRESSOR(LIB)                                                         \
                                                                                \
static int bl_##LIB##_compress(lua_State *L)                                    \
{                                                                               \
    const char *src = luaL_checkstring(L, 1);                                   \
    size_t src_len = lua_rawlen(L, 1);                                          \
    char *dst;                                                                  \
    size_t dst_len;                                                             \
    int n = bl_##LIB##_compress_core(L, src, src_len, &dst, &dst_len);          \
    if (n > 0) return n; /* error messages pushed by bl_##LIB##_compress_core */    \
    lua_pop(L, 1);                                                              \
    lua_pushlstring(L, dst, (size_t)(dst_len));                                 \
    free(dst);                                                                  \
    return 1;                                                                   \
}                                                                               \
                                                                                \
static int bl_##LIB##_decompress(lua_State *L)                                  \
{                                                                               \
    const char *src = luaL_checkstring(L, 1);                                   \
    size_t src_len = lua_rawlen(L, 1);                                          \
    char *dst;                                                                  \
    size_t dst_len;                                                             \
    int n = bl_##LIB##_decompress_core(L, src, src_len, &dst, &dst_len);        \
    if (n > 0) return n; /* error messages pushed by bl_##LIB##_decompress_core */  \
    if (n < 0)           /* string not compressed by LIB */                     \
    {                                                                           \
        lua_pushnil(L);                                                         \
        lua_pushstring(L, #LIB ": not a compressed string");                    \
        return 2;                                                               \
    }                                                                           \
    lua_pop(L, 1);                                                              \
    lua_pushlstring(L, dst, (size_t)(dst_len));                                 \
    free(dst);                                                                  \
    return 1;                                                                   \
}                                                                               \
                                                                                \
static const luaL_Reg LIB##lib[] =                                              \
{                                                                               \
    {"compress", bl_##LIB##_compress},                                          \
    {"decompress", bl_##LIB##_decompress},                                      \
    {NULL, NULL}                                                                \
};                                                                              \

#ifdef USE_MINILZO

int bl_minilzo_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
#define HEAP_ALLOC(var,size) \
    lzo_align_t __LZO_MMODEL var [ ((size) + (sizeof(lzo_align_t) - 1)) / sizeof(lzo_align_t) ]
    HEAP_ALLOC(wrkmem, LZO1X_1_MEM_COMPRESS);
    lzo_uint lzo_dst_len = src_len + src_len/16 + 64 + 3 + sizeof(t_z_header);
    lzo_bytep lzo_dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
    int r = lzo1x_1_compress(src, src_len, lzo_dst+sizeof(t_z_header), &lzo_dst_len, wrkmem);
    if (r != LZO_E_OK)
    {
        free(lzo_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "minilzo: lzo1x_1_compress failed (error: %d)", r);
        return 2;
    }
    ((t_z_header*)lzo_dst)->sig = LZO_SIG;
    ((t_z_header*)lzo_dst)->len = src_len;
    *dst = lzo_dst;
    *dst_len = lzo_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_minilzo_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == LZO_SIG)
    {
        lzo_uint lzo_dst_len = ((t_z_header*)src)->len;
        *dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_decompress_safe(src+sizeof(t_z_header), src_len-sizeof(t_z_header), *dst, &lzo_dst_len, NULL);
        if (r != LZO_E_OK)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "minilzo: lzo1x_decompress failed (error: %d)", r);
            return 2;
        }
        *dst_len = lzo_dst_len;
        return 0;
    }
    return -1;
}

COMPRESSOR(minilzo)

LUAMOD_API int luaopen_minilzo (lua_State *L)
{
    if (lzo_init() != LZO_E_OK)
    {
        luaL_error(L, "minilzo: lzo_init() failed !!!");
    }
    luaL_newlib(L, minilzolib);
    return 1;
}

#endif

#ifdef USE_LZO

int bl_lzo_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
#define HEAP_ALLOC(var,size) \
    lzo_align_t __LZO_MMODEL var [ ((size) + (sizeof(lzo_align_t) - 1)) / sizeof(lzo_align_t) ]
    HEAP_ALLOC(wrkmem, LZO1X_999_MEM_COMPRESS);
    lzo_uint lzo_dst_len = src_len + src_len/16 + 64 + 3 + sizeof(t_z_header);
    lzo_bytep lzo_dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
    int r = lzo1x_999_compress(src, src_len, lzo_dst+sizeof(t_z_header), &lzo_dst_len, wrkmem);
    if (r != LZO_E_OK)
    {
        free(lzo_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "lzo: lzo1x_999_compress failed (error: %d)", r);
        return 2;
    }
    ((t_z_header*)lzo_dst)->sig = LZO_SIG;
    ((t_z_header*)lzo_dst)->len = src_len;
    *dst = lzo_dst;
    *dst_len = lzo_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_lzo_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == LZO_SIG)
    {
        lzo_uint lzo_dst_len = ((t_z_header*)src)->len;
        *dst = (lzo_bytep)malloc(sizeof(lzo_byte)*lzo_dst_len);
        int r = lzo1x_decompress_safe(src+sizeof(t_z_header), src_len-sizeof(t_z_header), *dst, &lzo_dst_len, NULL);
        if (r != LZO_E_OK)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "lzo: lzo1x_decompress failed (error: %d)", r);
            return 2;
        }
        *dst_len = lzo_dst_len;
        return 0;
    }
    return -1;
}

COMPRESSOR(lzo)

LUAMOD_API int luaopen_lzo (lua_State *L)
{
    if (lzo_init() != LZO_E_OK)
    {
        luaL_error(L, "lzo: lzo_init() failed !!!");
    }
    luaL_newlib(L, lzolib);
    return 1;
}

#endif

#ifdef USE_UCL

int bl_ucl_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    ucl_uint ucl_dst_len = src_len + src_len/8 + 256 + sizeof(t_z_header);
    ucl_bytep ucl_dst = (ucl_bytep)malloc(sizeof(ucl_byte)*ucl_dst_len);
    int r = ucl_nrv2e_99_compress(src, src_len, ucl_dst+sizeof(t_z_header), &ucl_dst_len, NULL, UCL_LEVEL, NULL, NULL);
    if (r != UCL_E_OK)
    {
        free(ucl_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "ucl: ucl_nrv2e_99_compress failed (error: %d)", r);
        return 2;
    }
    ((t_z_header*)ucl_dst)->sig = UCL_SIG;
    ((t_z_header*)ucl_dst)->len = src_len;
    *dst = ucl_dst;
    *dst_len = ucl_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_ucl_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == UCL_SIG)
    {
        ucl_uint ucl_dst_len = ((t_z_header*)src)->len;
        *dst = (ucl_bytep)malloc(sizeof(ucl_byte)*ucl_dst_len+65000);
        int r = ucl_nrv2e_decompress_safe_8(src+sizeof(t_z_header), src_len-sizeof(t_z_header), *dst, &ucl_dst_len, NULL);
        if (r != UCL_E_OK)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "ucl: ucl_nrv2e_decompress_safe_8 failed (error: %d)", r);
            return 2;
        }
        *dst_len = ucl_dst_len;
        return 0;
    }
    return -1;
}

COMPRESSOR(ucl)

LUAMOD_API int luaopen_ucl (lua_State *L)
{
    if (ucl_init() != UCL_E_OK)
    {
        luaL_error(L, "ucl: ucl_init() failed !!!");
    }
    luaL_newlib(L, ucllib);
    return 1;
}

#endif

#ifdef USE_QLZ

int bl_qlz_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    char *qlz_dst;
    size_t qlz_dst_len;
    if (src_len == 0)
    {
        /* specific case for the empty string (the decompressor crashes on empty strings) */
        qlz_dst = (char*)malloc(sizeof(t_z_header));
        qlz_dst_len = 0;
    }
    else
    {
        qlz_state_compress *state_compress = (qlz_state_compress *)malloc(sizeof(qlz_state_compress));
        qlz_dst = (char*)malloc(src_len + 400 + sizeof(t_z_header));
        qlz_dst_len = qlz_compress(src, qlz_dst+sizeof(t_z_header), src_len, state_compress);
        free(state_compress);
    }

    ((t_z_header*)qlz_dst)->sig = QLZ_SIG;
    ((t_z_header*)qlz_dst)->len = src_len;
    *dst = qlz_dst;
    *dst_len = qlz_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_qlz_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == QLZ_SIG)
    {
        if (((t_z_header*)src)->len == 0)
        {
            /* specific case for the empty string (the decompressor crashes on empty strings) */
            *dst_len = 0;
            *dst = NULL;
        }
        else
        {
            qlz_state_decompress *state_decompress = (qlz_state_decompress *)malloc(sizeof(qlz_state_decompress));
            *dst_len = ((t_z_header*)src)->len;
            *dst = (char*)malloc(*dst_len);
            *dst_len = qlz_decompress(src+sizeof(t_z_header), *dst, state_decompress);
            free(state_decompress);
        }
        return 0;
    }
    return -1;
}

COMPRESSOR(qlz)

LUAMOD_API int luaopen_qlz (lua_State *L)
{
    luaL_newlib(L, qlzlib);
    return 1;
}

#endif

#ifdef USE_LZ4

int bl_lz4_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    char *lz4_dst = (char*)malloc(LZ4_COMPRESSBOUND(src_len) + sizeof(t_z_header));
    int lz4_dst_len = LZ4_compress((char*)src, lz4_dst+sizeof(t_z_header), src_len);
    ((t_z_header*)lz4_dst)->sig = LZ4_SIG;
    ((t_z_header*)lz4_dst)->len = src_len;
    *dst = lz4_dst;
    *dst_len = lz4_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_lz4hc_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    char *lz4_dst = (char*)malloc(LZ4_COMPRESSBOUND(src_len) + sizeof(t_z_header));
    int lz4_dst_len = LZ4_compressHC((char*)src, lz4_dst+sizeof(t_z_header), src_len);
    ((t_z_header*)lz4_dst)->sig = LZ4_SIG;
    ((t_z_header*)lz4_dst)->len = src_len;
    *dst = lz4_dst;
    *dst_len = lz4_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_lz4_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == LZ4_SIG)
    {
        *dst_len = ((t_z_header*)src)->len + 3;
        *dst = (char*)malloc(*dst_len);
        int r = LZ4_decompress_safe((char*)(src+sizeof(t_z_header)), *dst, src_len-sizeof(t_z_header), *dst_len);
        if (r < 0)
        {
            free(dst);
            lua_pushnil(L);
            lua_pushfstring(L, "lz4: LZ4_decompress_safe (error: %d)", *dst_len);
            return 2;
        }
        *dst_len = r;
        return 0;
    }
    return -1;
}

#define bl_lz4hc_decompress_core bl_lz4_decompress_core

COMPRESSOR(lz4)
COMPRESSOR(lz4hc)

LUAMOD_API int luaopen_lz4 (lua_State *L)
{
    luaL_newlib(L, lz4lib);
    return 1;
}

LUAMOD_API int luaopen_lz4hc (lua_State *L)
{
    luaL_newlib(L, lz4hclib);
    return 1;
}

#endif

#ifdef USE_LZF

int bl_lzf_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    char *lzf_dst;
    unsigned int lzf_dst_len;
    if (src_len == 0)
    {
        /* specific case for the empty string (the decompressor crashes on empty strings) */
        lzf_dst = (char*)malloc(sizeof(t_z_header));
        lzf_dst_len = 0;
    }
    else
    {
        lzf_dst = (char*)malloc(src_len+src_len/16+16 + sizeof(t_z_header));
        lzf_dst_len = lzf_compress((char*)src, src_len, lzf_dst+sizeof(t_z_header), src_len+src_len/16+16);
    }
    ((t_z_header*)lzf_dst)->sig = LZF_SIG;
    ((t_z_header*)lzf_dst)->len = src_len;
    *dst = lzf_dst;
    *dst_len = lzf_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_lzf_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == LZF_SIG)
    {
        if (((t_z_header*)src)->len == 0)
        {
            /* specific case for the empty string (the decompressor crashes on empty strings) */
            *dst_len = 0;
            *dst = NULL;
        }
        else
        {
            *dst_len = ((t_z_header*)src)->len+16;
            *dst = (char*)malloc(*dst_len);
            unsigned int r = lzf_decompress((char*)(src+sizeof(t_z_header)), src_len-sizeof(t_z_header), *dst, *dst_len);
            if (r == 0)
            {
                free(dst);
                lua_pushnil(L);
                lua_pushfstring(L, "lzf: lzf_decompress");
                return 2;
            }
            *dst_len = r;
        }
        return 0;
    }
    return -1;
}

COMPRESSOR(lzf)

LUAMOD_API int luaopen_lzf (lua_State *L)
{
    luaL_newlib(L, lzflib);
    return 1;
}

#endif

#ifdef USE_ZLIB

int bl_zlib_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    uLongf zlib_dst_len = src_len + src_len/10 + 12;
    Bytef *zlib_dst = (char*)malloc(zlib_dst_len + sizeof(t_z_header));
    int r = compress2(zlib_dst+sizeof(t_z_header), &zlib_dst_len, src, src_len, ZLIB_LEVEL);
    if (r != Z_OK)
    {
        free(zlib_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "zlib: compress2 failed (error: %d)", r);
        return 2;
    }
    ((t_z_header*)zlib_dst)->sig = ZLIB_SIG;
    ((t_z_header*)zlib_dst)->len = src_len;
    *dst = zlib_dst;
    *dst_len = zlib_dst_len;
    *dst_len += sizeof(t_z_header);
    return 0;
}

int bl_zlib_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == ZLIB_SIG)
    {
        *dst_len = ((t_z_header*)src)->len;
        *dst = (char*)malloc(*dst_len);
        int r = uncompress(*dst, (uLongf *)dst_len, (char*)(src+sizeof(t_z_header)), src_len-sizeof(t_z_header));
        if (r != Z_OK)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "z: uncompress failed (error: %d)", r);
            return 2;
        }
        return 0;
    }
    return -1;
}

COMPRESSOR(zlib)

LUAMOD_API int luaopen_zlib (lua_State *L)
{
    luaL_newlib(L, zliblib);
    return 1;
}

#endif

#ifdef USE_LZMA

#define LZMA_EXTREME 0
#define LZMA_CHECK LZMA_CHECK_CRC64

int bl_lzma_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    uint32_t preset = LZMA_LEVEL | (LZMA_EXTREME ? LZMA_PRESET_EXTREME : 0);
    lzma_check check = LZMA_CHECK;
    lzma_stream strm = LZMA_STREAM_INIT;
    size_t lzma_dst_len = src_len + src_len/8 + 256;
    uint8_t *lzma_dst = (uint8_t*)malloc(lzma_dst_len + sizeof(t_z_header));
    int out_finished = 0;
    lzma_action action;
    lzma_ret ret;
    ret = lzma_easy_encoder(&strm, preset, check);
    if (ret != LZMA_OK)
    {
        free(lzma_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "lzma: lzma_easy_encoder failed (error: %d)", ret);
        return 2;
    }
    strm.next_in = src;
    strm.avail_in = src_len;
    action = LZMA_FINISH;
    strm.next_out = lzma_dst + sizeof(t_z_header);
    strm.avail_out = lzma_dst_len;
    ret = lzma_code(&strm, action);
    if (ret != LZMA_STREAM_END)
    {
        free(lzma_dst);
        lua_pushnil(L);
        lua_pushfstring(L, "lzma: lzma_code failed (error: %d)", ret);
        return 2;
    }
    lzma_dst_len -= strm.avail_out;
    ((t_z_header*)lzma_dst)->sig = LZMA_SIG;
    ((t_z_header*)lzma_dst)->len = src_len;
    *dst = lzma_dst;
    *dst_len = lzma_dst_len;
    *dst_len += sizeof(t_z_header);
    lzma_end(&strm);
    return 0;
}

int bl_lzma_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    if (((t_z_header*)src)->sig == LZMA_SIG)
    {
        lzma_stream strm = LZMA_STREAM_INIT;
        const uint32_t flags = LZMA_TELL_UNSUPPORTED_CHECK | LZMA_CONCATENATED;
        const uint64_t memory_limit = UINT64_MAX;
        *dst_len = ((t_z_header*)src)->len;
        *dst = (uint8_t*)malloc(*dst_len);
        lzma_action action;
        lzma_ret ret;
        ret = lzma_stream_decoder(&strm, memory_limit, flags);
        if (ret != LZMA_OK)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "lzma: lzma_stream_decoder failed (error: %d)", ret);
            return 2;
        }
        strm.next_in = src + sizeof(t_z_header);
        strm.avail_in = src_len - sizeof(t_z_header);
        action = LZMA_FINISH;
        strm.next_out = *dst;
        strm.avail_out = *dst_len;
        ret = lzma_code(&strm, action);
        if (ret != LZMA_STREAM_END)
        {
            free(*dst);
            lua_pushnil(L);
            lua_pushfstring(L, "lzma: lzma_code failed (error: %d)", ret);
            return 2;
        }
        return 0;
    }
    return -1;
}

COMPRESSOR(lzma)

LUAMOD_API int luaopen_lzma(lua_State *L)
{
    luaL_newlib(L, lzmalib);
    return 1;
}
#endif

int bl_z_compress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{
    char *smallest = NULL;
    size_t smallest_len = (size_t)-1;
    char *compressed;
    size_t compressed_len;

#define COMPRESS(LIB)                                                                   \
{                                                                                       \
    int r = bl_##LIB##_compress_core(L, src, src_len, &compressed, &compressed_len);    \
    if (r > 0) return r;                                                                \
    if (compressed_len < smallest_len)                                                  \
    {                                                                                   \
        if (smallest) free(smallest);                                                   \
        smallest = compressed;                                                          \
        smallest_len = compressed_len;                                                  \
    }                                                                                   \
}

#ifdef USE_MINILZO
    COMPRESS(minilzo)
#endif
#ifdef USE_LZO
    COMPRESS(lzo)
#endif
#ifdef USE_QLZ
    COMPRESS(qlz)
#endif
#ifdef USE_LZ4
    COMPRESS(lz4)
    COMPRESS(lz4hc)
#endif
#ifdef USE_LZF
    COMPRESS(lzf)
#endif
#ifdef USE_ZLIB
    COMPRESS(zlib)
#endif
#ifdef USE_UCL
    COMPRESS(ucl)
#endif
#ifdef USE_LZMA
    COMPRESS(lzma)
#endif

#undef COMPRESS

    if (smallest)
    {
        *dst = smallest;
        *dst_len = smallest_len;
    }
    else
    {
        lua_pushnil(L);
        lua_pushstring(L, "z: can not compress");
        return 2;
    }
    return 0;
}

int bl_z_decompress_core(lua_State *L, const char *src, size_t src_len, char **dst, size_t *dst_len)
{

#define DECOMPRESS(LIB)                                                 \
{                                                                       \
    int r = bl_##LIB##_decompress_core(L, src, src_len, dst, dst_len);  \
    if (r > 0) return r; /* decompression error */                      \
    if (r == 0) return r;/* decompression done */                       \
    /* r < 0 => string not compressed by LIB */                         \
}

#ifdef USE_MINILZO
    DECOMPRESS(minilzo)
#endif
#ifdef USE_LZO
    DECOMPRESS(lzo)
#endif
#ifdef USE_QLZ
    DECOMPRESS(qlz)
#endif
#ifdef USE_LZ4
    DECOMPRESS(lz4)
    DECOMPRESS(lz4hc)
#endif
#ifdef USE_LZF
    DECOMPRESS(lzf)
#endif
#ifdef USE_ZLIB
    DECOMPRESS(zlib)
#endif
#ifdef USE_UCL
    DECOMPRESS(ucl)
#endif
#ifdef USE_LZMA
    DECOMPRESS(lzma)
#endif

    return -1;
#undef DECOMPRESS
}

COMPRESSOR(z)

LUAMOD_API int luaopen_z (lua_State *L)
{
    luaL_newlib(L, zlib);
    return 1;
}

#undef COMPRESSOR

#endif

/*******************************************************************/
/* crypt: cryptography library                                     */
/*******************************************************************/

#ifdef USE_CRYPT

#ifdef __MINGW32__
static HCRYPTPROV hProv = 0;
#endif

static int crypt_rnd(lua_State *L)
{
    int bytes = luaL_checkinteger(L, 1);
    char *buffer = (char*)malloc(bytes);
    if (!buffer) luaL_error(L, "crypt: not enought memory");
#ifdef __MINGW32__
    if (hProv == 0)
    {
        if (!CryptAcquireContext(&hProv, NULL, NULL, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT))
            luaL_error(L, "crypt: CryptAcquireContext error");
    }
    CryptGenRandom(hProv, bytes, buffer);
#else
    FILE *f = fopen("/dev/urandom", "rb");
    fread(buffer, 1, bytes, f);
    fclose(f);
#endif
    lua_pushlstring(L, buffer, bytes);
    free(buffer);
    return 1;
}

#include "btea.c"

#define MIN(a, b) ((a) <= (b) ? (a) : (b))

static int crypt_btea(lua_State *L, int encrypt)
{
    const char *key_str = luaL_checkstring(L, 1);
    size_t key_len = lua_rawlen(L, 1);
    const char *src = luaL_checkstring(L, 2);
    size_t src_len = lua_rawlen(L, 2);

    uint32_t key[4] = {0, 0, 0, 0};
    memcpy(key, key_str, MIN(16, key_len));

    int buffer_len = (src_len + sizeof(uint32_t) - 1) / sizeof(uint32_t);
    uint32_t *buffer = (uint32_t*)malloc(buffer_len*sizeof(uint32_t));
    if (!buffer) luaL_error(L, "crypt: not enought memory");
    memset(buffer, 0, buffer_len*sizeof(uint32_t));
    memcpy(buffer, src, src_len);
    btea(buffer, encrypt*buffer_len, key);

    lua_pushlstring(L, (const char *)buffer, buffer_len*sizeof(uint32_t));
    free(buffer);
    return 1;
}

static int crypt_btea_encrypt(lua_State *L)
{
    return crypt_btea(L, +1);
}

static int crypt_btea_decrypt(lua_State *L)
{
    return crypt_btea(L, -1);
}

static const luaL_Reg cryptlib[] =
{
    {"rnd", crypt_rnd},
    {"btea_encrypt", crypt_btea_encrypt},
    {"btea_decrypt", crypt_btea_decrypt},
    {NULL, NULL}
};

LUAMOD_API int luaopen_crypt(lua_State *L)
{
    luaL_newlib(L, cryptlib);
    return 1;
}

#endif
