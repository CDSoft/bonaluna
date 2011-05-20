/* BonaLuna

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2 alpha
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.
*/

/* Inspired by srlua */

typedef enum
{
    START_SIG       = 0x474C5545,
    END_SIG         = 0x23454E44,
} t_block_sig;

typedef enum
{
    LUA_BLOCK       = 0x234C5541,
    STRING_BLOCK    = 0x23535452,
    FILE_BLOCK      = 0x23524553,
    DIR_BLOCK       = 0x23444952,
} t_block_type;

/* also define compile in glue.lua */
#define COMPILE

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

static int dostring (lua_State *L, const char *s, const char *name);
static int docall (lua_State *L, int narg, int nres);
static int report (lua_State *L, int status);

#define cant(x, name) luaL_error(L, "cannot %s %s: %s", x, name, strerror(errno))

static int glue(lua_State *L, char **argv)
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

    /* collect arguments */
    for (i=1; argv[i]; i++) ; /* count */
    lua_createtable(L, i-1, 1);
    for (i=0; argv[i]; i++)
    {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    /* open the glue */
    f = fopen(argv[0], "rb");
    if (f==NULL) cant("open", argv[0]);

    /* search for the start block */
    if (fseek(f, -sizeof(t_end_block), SEEK_END) != 0) cant("seek", argv[0]);
    end = ftell(f);
    //printf("%08X - %d - %d\n", ftell(f), sizeof(t_end_block), feof(f));
    if (fread(&end_block, sizeof(t_end_block), 1, f) != 1) cant("read1", argv[0]);
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
    if (fread(&start_block, sizeof(t_start_block), 1, f) != 1) cant("read2", argv[0]);
    if (start_block.sig != START_SIG)
    {
        /* Bad start signature */
        fclose(f);
        luaL_error(L, "bad start signature in %s", argv[0]);
        return 0;
    }

    /* load the blocks */
    while (ftell(f) < end && (fread(&block, sizeof(block), 1, f) == 1))
    {
        switch (block.type)
        {
            case LUA_BLOCK:
                name = (char*)malloc(block.name_len);
                if (fread(name, sizeof(char), block.name_len, f) != block.name_len) cant("read3", argv[0]);
                //printf("Run %s\n", name);
                data = (char*)malloc(block.data_len);
                if (fread(data, sizeof(char), block.data_len, f) != block.data_len) cant("read4", argv[0]);
#ifdef COMPILE
                status = luaL_loadbuffer(L, data, block.data_len, name);
                if (status == LUA_OK) status = docall(L, 0, 0);
                status = report(L, status);
#else
                status = dostring(L, data, name);
#endif
                free(name);
                free(data);
                if (status != LUA_OK) return 0;
                break;
            case STRING_BLOCK:
                name = (char*)malloc(block.name_len);
                if (fread(name, sizeof(char), block.name_len, f) != block.name_len) cant("read5", argv[0]);
                //printf("Load %s\n", name);
                data = (char*)malloc(block.data_len);
                if (fread(data, sizeof(char), block.data_len, f) != block.data_len) cant("read6", argv[0]);
                lua_pushlstring(L, data, block.data_len);
                lua_setglobal(L, name);
                free(name);
                free(data);
                break;
            case FILE_BLOCK:
                name = (char*)malloc(block.name_len);
                if (fread(name, sizeof(char), block.name_len, f) != block.name_len) cant("read7", argv[0]);
                data = (char*)malloc(block.data_len);
                if (fread(data, sizeof(char), block.data_len, f) != block.data_len) cant("read8", argv[0]);
                //printf("File %s\n", name);
                if (stat(name, &st) < 0)
                {
                    /* the file does not yet exist */
                    FILE *fd = fopen(name, "wb");
                    if (fwrite(data, sizeof(char), block.data_len, fd) != block.data_len) cant("write", name);
                    fclose(fd);
                }
                free(name);
                free(data);
                break;
            case DIR_BLOCK:
                name = (char*)malloc(block.name_len);
                if (fread(name, sizeof(char), block.name_len, f) != block.name_len) cant("read9", argv[0]);
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
                free(name);
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
    if (fread(&end_block, sizeof(t_end_block), 1, f) != 1) cant("read10", argv[0]);
    fclose(f);
    if (end_block.sig != END_SIG)
    {
        luaL_error(L, "bad end signature in %s", argv[0]);
        return 0;
    }

    return 1;
}
