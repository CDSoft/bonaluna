/* BonaLuna

Copyright (C) 2010-2017 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2017 Lua.org, PUC-Rio

Freely available under the terms of the MIT license.
*/

/* Inspired by srlua */

typedef enum
{
    START_SIG       = 0x45554C47,
    END_SIG         = 0x444E4523,
} t_block_sig;

typedef enum
{
    LUA_BLOCK       = 0x41554C23,
    STRING_BLOCK    = 0x52545323,
    FILE_BLOCK      = 0x53455223,
    DIR_BLOCK       = 0x52494423,
} t_block_type;

typedef struct
{
    t_block_sig sig;
} t_start_block;

typedef struct
{
    t_block_type type;
    unsigned int name_len;
    unsigned int data_len;
} t_block;

typedef struct
{
    t_block_sig sig;
    unsigned int size;
} t_end_block;

static int docall (lua_State *L, int narg, int nres);
static int report (lua_State *L, int status);

#define cant(x, name) luaL_error(L, "cannot %s %s: %s", x, name, strerror(errno))

static void glue_setarg(lua_State *L, char **argv, int argc, int script, char *exename)
{
    int i;
    lua_newtable(L);
    lua_pushinteger(L, -1);
    lua_pushstring(L, exename);
    lua_rawset(L, -3);
    for (i=1; argv[i]; i++)
    {
        lua_pushinteger(L, i);
        lua_pushstring(L, argv[i]);
        lua_rawset(L, -3);
    }
    lua_setglobal(L, "arg");
}

static void glue_setarg0(lua_State *L, char *arg0)
{
    lua_getglobal(L, "arg");
    lua_pushinteger(L, 0);
    lua_pushstring(L, arg0);
    lua_rawset(L, -3);
    lua_remove(L, 0);
}

#ifdef __MINGW32__
/* GetModuleFileName defined in windows.h */
#else
static int GetModuleFileName(void *null, char *exename, size_t bufsize)
{
    char link[32];
    ssize_t n;
    sprintf(link, "/proc/%d/exe", getpid());
    n = readlink(link, exename, bufsize);
    if (n<0) return 0;
    exename[n] = '\0';
    return 1;
}
#endif

static int glue(lua_State *L, char **argv, int argc, int script)
{
    int status;
    int i;
    FILE *f;
    t_start_block start_block;
    t_end_block end_block;
    t_block block;
    char *name, *data;
    struct stat st;
    long int end;
    char pathexe[BL_PATHSIZE];
    char path[BL_PATHSIZE];
    char *path_end; // pointer to the end of the path in the executable name
    char *p;

    /* collect arguments */
    if (!GetModuleFileName(NULL, path, sizeof(path))) cant("find", argv[0]);
    strcpy(pathexe, path);

    /* open the glue */
    f = fopen(path, "rb");
    if (f==NULL) cant("open", argv[0]);

    /* path = dirname of the executable */
    path_end = NULL;
    for (p=path; *p; p++)
        if (*p==*LUA_DIRSEP)
            path_end = p+1;

    /* search for the start block */
    if (fseek(f, -(ssize_t)sizeof(t_end_block), SEEK_END) != 0) cant("seek", argv[0]);
    end = ftell(f);
    //printf("%08X - %d - %d\n", ftell(f), sizeof(t_end_block), feof(f));
    if (fread(&end_block, sizeof(t_end_block), 1, f) != 1) cant("read", argv[0]);
    if (end_block.sig != END_SIG)
    {
        /* Nothing to load */
        //printf("Nothing to load\n");
        //printf("%08X\n", end_block.sig);
        fclose(f);
        return 1;
    }
    //printf("size = %d\n", -end_block.size);

    if (fseek(f, -(long int)end_block.size, SEEK_END) != 0) cant("seek", argv[0]);
    //printf("%08X - %d - %d\n", ftell(f), sizeof(t_start_block), feof(f));
    if (fread(&start_block, sizeof(t_start_block), 1, f) != 1) cant("read", argv[0]);
    if (start_block.sig != START_SIG)
    {
        /* Bad start signature */
        fclose(f);
        luaL_error(L, "bad start signature in %s", argv[0]);
        return 0;
    }

#ifdef USE_Z

#define UNCOMPRESS_DATA()                                                                           \
        char *uncompressed;                                                                         \
        size_t uncompressed_len;                                                                    \
        int n = bl_z_decompress_core(L, data, block.data_len, &uncompressed, &uncompressed_len);    \
        if (n == 0) /* decompression is ok */                                                       \
        {                                                                                           \
            /* The data was compressed */                                                           \
            free(data);                                                                             \
            data = uncompressed;                                                                    \
            block.data_len = uncompressed_len;                                                      \
        }                                                                                           \
        else                                                                                        \
        {                                                                                           \
            /* The data was not compressed */                                                       \
            lua_pop(L, n);                                                                          \
        }                                                                                           \

#else

#define UNCOMPRESS_DATA() /* no compression library */

#endif

#define READ_DATA()                                                                                 \
{                                                                                                   \
    name = (char*)malloc(block.name_len);                                                           \
    if (fread(name, sizeof(char), block.name_len, f) != block.name_len) cant("read", argv[0]);      \
    if (*name == ':')                                                                               \
    {                                                                                               \
        if (*(name+1) != '\\' && *(name+1) != '/') luaL_error(L, "bad path: %s", name);             \
        strcpy(path_end, name+2);                                                                   \
        free(name);                                                                                 \
        name = path;                                                                                \
    }                                                                                               \
    if (block.data_len == 0)                                                                        \
    {                                                                                               \
        data = NULL;                                                                                \
    }                                                                                               \
    else                                                                                            \
    {                                                                                               \
        data = (char*)malloc(block.data_len);                                                       \
        if (fread(data, sizeof(char), block.data_len, f) != block.data_len) cant("read", argv[0]);  \
        UNCOMPRESS_DATA();                                                                          \
    }                                                                                               \
}

#define FREE_DATA()                 \
{                                   \
    if (name != path) free(name);   \
    if (data) free(data);           \
}

    /* load the blocks */
    while (ftell(f) < end && fread(&block, sizeof(block), 1, f) == 1)
    {
        switch (block.type)
        {
            case LUA_BLOCK:
                READ_DATA();
                glue_setarg(L, argv, argc, script, pathexe);
                glue_setarg0(L, name);
                //printf("Run %s\n%s\n", name, data);
                /* check LUA_SIGNATURE to identify precompiled chunks */
                if (data[0]=='\033' && data[1]=='L' && data[2]=='u' && data[3]=='a')
                {
                    /* precompiled chunk */
                    status = luaL_loadbuffer(L, data, block.data_len, name);
                    if (status == LUA_OK) status = docall(L, 0, 0);
                    status = report(L, status);
                }
                else
                {
                    /* plain Lua source */
                    //status = dostring(L, data, name);
                    status = luaL_loadbuffer(L, data, block.data_len, name);
                    if (status == LUA_OK) status = docall(L, 0, 0);
                    status = report(L, status);
                }
                FREE_DATA();
                /* Restore the arg variable */
                createargtable(L, argv, argc, script);
                if (status != LUA_OK) return 0;
                break;
            case STRING_BLOCK:
                READ_DATA();
                //printf("Load %s\n", name);
                lua_pushlstring(L, data, block.data_len);
                lua_setglobal(L, name);
                FREE_DATA();
                break;
            case FILE_BLOCK:
                READ_DATA()
                //printf("File %s\n", name);
                if (stat(name, &st) < 0)
                {
                    /* the file does not yet exist */
                    FILE *fd = fopen(name, "wb");
                    if (fwrite(data, sizeof(char), block.data_len, fd) != block.data_len) cant("write", name);
                    fclose(fd);
                }
                FREE_DATA();
                break;
            case DIR_BLOCK:
                READ_DATA();
                //printf("Dir %s\n", name);
                if (stat(name, &st) < 0)
                {
                    /* the directory does not yet exist */
                    #ifdef __MINGW32__
                        if (mkdir(name)!=0) cant("mkdir", name);
                    #else
                        if (mkdir(name, 0755)!=0) cant("mkdir", name);
                    #endif
                }
                FREE_DATA();
                break;
            default:
                /* Bad block type */
                fclose(f);
                //printf("block type : %08X\n", block.type);
                luaL_error(L, "bad block type in %s", argv[0]);
                return 0;
        }
    }

    //printf("C'est fini...\n");

    /* check the end signature */
    //printf("%08X - %d - %d\n", ftell(f), sizeof(t_end_block), feof(f));
    if (fread(&end_block, sizeof(t_end_block), 1, f) != 1) cant("read", argv[0]);
    fclose(f);
    if (end_block.sig != END_SIG)
    {
        luaL_error(L, "bad end signature in %s", argv[0]);
        return 0;
    }

    return 1;
}
