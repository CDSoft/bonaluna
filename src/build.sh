#!/bin/bash

BUILD=build

LUA_SRC=lua-5.2.0-alpha
LUA_URL=http://www.lua.org/work/$LUA_SRC.tar.gz
LZO_SRC=minilzo.205
LZO_URL=http://www.oberhumer.com/opensource/lzo/download/minilzo-2.05.tar.gz
QLZ_SRC=quicklz
QLZ_URL=http://www.quicklz.com/

function error()
{
    echo $*
    exit 1
}

# Command line
##############

clean=false
while [ -n "$1" ]
do
    case "$1" in
        --clean)    clean=true ;;
        *)          break;;
    esac
    shift
done
TARGET=$BUILD/$1
BL=$2
CC=$3
BITS=$4

if $clean
then
    echo "Clean..."
    rm -rf $BUILD $LUA_SRC
    exit
fi

mkdir -p $BUILD

# Check parameters
##################

[ -x /usr/bin/$CC ] || error "Unknown compiler: $CC"
[ "$BITS" = "32" ] || [ "$BITS" = "64" ] || error "Wrong integer size (should be 32 or 64)"

CC_OPTS="-O2 -std=gnu99"
CC_LIBS="-lm"
LUA_CONF=
BONALUNA_CONF="-DVERSION=\"$(cat ../VERSION)\""

case "$(uname)" in
    MINGW32*)   PLATFORM=Windows ;;
    *)          case "$CC" in
                    gcc)        PLATFORM=Linux ;;
                    *mingw32*)  PLATFORM=Windows ;;
                esac
                ;;
esac

case "$PLATFORM" in
    Linux)      LUA_CONF="$LUA_CONF -DLUA_USE_POSIX -DLUA_USE_DLOPEN -DLUA_USE_READLINE"
                CC_LIBS="$CC_LIBS -ldl -lreadline"
                ;;
    Windows)    CC_LIBS="$CC_LIBS -lws2_32"
                ;;
esac


BONALUNA_CONF="$BONALUNA_CONF -DBONALUNA_PLATFORM=\"$PLATFORM\""

# Download Lua sources
######################

[ -e $(basename $LUA_URL) ] || wget $LUA_URL
[ -e $LUA_SRC ] || tar xzf $(basename $LUA_URL)

[ -e $(basename $LZO_URL) ] || wget $LZO_URL
[ -e $LZO_SRC ] || tar xzf $(basename $LZO_URL)

mkdir -p $QLZ_SRC
(   cd $QLZ_SRC
    [ -e $QLZ_SRC.c ] || wget $QLZ_URL/$QLZ_SRC.c
    [ -e $QLZ_SRC.h ] || wget $QLZ_URL/$QLZ_SRC.h
)

# Target initialisation
#######################

mkdir -p $TARGET
cp -f $LUA_SRC/src/* $TARGET/
cp -f $LZO_SRC/*.{c,h} $TARGET/
cp -f $QLZ_SRC/*.{c,h} $TARGET/

# BonaLuna patches
##################

awk '
    /LUA_COPYRIGHT/ {
        print "printf(\"%s\\n\", BONALUNA_COPYRIGHT);"
        print
        next
    }
    /handle_luainit\(L\)/ {
        print
        print "if (!glue(L, argv)) return 0;"
        next
    }
    {print}
' $LUA_SRC/src/lua.c > $TARGET/lua.c

awk '
    /lauxlib.h/ {
        print "#include \"bonaluna.h\""
    }
    /LUA_MATHLIBNAME/ {
        print "  {LUA_FSLIBNAME,  luaopen_fs},"
        print "  {LUA_PSLIBNAME,  luaopen_ps},"
        print "  {LUA_SYSLIBNAME, luaopen_sys},"
        print "  {LUA_STRUCTLIBNAME, luaopen_struct},"
        print "  {LUA_RLLIBNAME, luaopen_readline},"
        print "  {LUA_LZLIBNAME, luaopen_lz},"
        }
    {print}
' $LUA_SRC/src/linit.c > $TARGET/linit.c

sed -i 's/pushclosure/lvm_pushclosure/g' $TARGET/lvm.c
sed -i 's/pushclosure/lparser_pushclosure/g' $TARGET/lparser.c

[ $BITS = 64 ] && awk '
    /#define[ \t]*LUA_NUMBER_DOUBLE/ {
        print "// #define LUA_NUMBER_DOUBLE"
        next
    }
    /#define[ \t]*LUA_NUMBER[ \t]*double/ {
        print "#define LUA_NUMBER long double"
        print "#define LUA_USELONGLONG"
        print "#define l_tg(x) (x##l)"
        next
    }
    /#define[ \t]*LUA_NUMBER_SCAN/ {
        print "#define LUA_NUMBER_SCAN \"%Lf\""
        next
    }
    /#define[ \t]*LUA_NUMBER_FMT/ {
        print "#define LUA_NUMBER_FMT \"%.14Lg\""
        next
    }
    /#define[ \t]*LUA_NUMBER_FMT/ {
        print "#define LUA_NUMBER_FMT \"%.14Lg\""
        next
    }
    /#define[ \t]*LUAI_MAXNUMBER2STR/ {
        print "#define LUAI_MAXNUMBER2STR 64"
        next
    }
    /#define[ \t]*lua_str2number/ {
        print "#define lua_str2number(s,p) strtold((s), (p))"
        next
    }
    /#define[ \t]*LUA_INTEGER/ {
        print "#define LUA_INTEGER long long"
        next
    }
    /#define[ \t]*LUA_UNSIGNED/ {
        print "#define LUA_UNSIGNED unsigned long long"
        next
    }
    {print}
' $LUA_SRC/src/luaconf.h > $TARGET/luaconf.h

[ $BITS = 64 ] && awk '
    /#define[ \t]*LUA_BITLIBNAME/ {
        print
        print "#define LUA_BITLIB64NAME \"bit64\""
        next
    }
    /luaopen_bit32/ {
        print
        print "LUAMOD_API int (luaopen_bit64) (lua_State *L);"
        next
    }
    {print}
' $LUA_SRC/src/lualib.h > $TARGET/lualib.h

[ $BITS = 64 ] && sed \
    -e "s/32/64/g" \
    -e "s/\(NBITS\)/\1$BITS/g" \
    -e "s/\(ALLONES\)/\1$BITS/g" \
    -e "s/\(trim\)/\1$BITS/g" \
    -e "s/\(getuintarg\)/\1$BITS/g" \
    -e "s/\(andaux\)/\1$BITS/g" \
    -e "s/\(b_and\)/\1$BITS/g" \
    -e "s/\(b_test\)/\1$BITS/g" \
    -e "s/\(b_or\)/\1$BITS/g" \
    -e "s/\(b_xor\)/\1$BITS/g" \
    -e "s/\(b_not\)/\1$BITS/g" \
    -e "s/\(b_shift\)/\1$BITS/g" \
    -e "s/\(b_lshift\)/\1$BITS/g" \
    -e "s/\(b_rshift\)/\1$BITS/g" \
    -e "s/\(b_arshift\)/\1$BITS/g" \
    -e "s/\(b_rot\)/\1$BITS/g" \
    -e "s/\(b_lrot\)/\1$BITS/g" \
    -e "s/\(b_rrot\)/\1$BITS/g" \
    -e "s/\(bitlib\)/\1$BITS/g" \
    $TARGET/lbitlib.c > $TARGET/lbitlib64.c
[ $BITS = 64 ] && CC_LIBS="$CC_LIBS $TARGET/lbitlib64.c"

[ $BITS = 64 ] && awk '
    /LUA_BITLIBNAME/ {
        print "  {LUA_BITLIB64NAME,  luaopen_bit64},"
        }
    {print}
' $TARGET/linit.c > /tmp/linit.c
[ $BITS = 64 ] && mv /tmp/linit.c $TARGET/linit.c

# LZO patches
#############

sed -i 's/__LZO_IN_MINLZO/__LZO_IN_MINILZO/g' $TARGET/minilzo.c

# QLZ patches
#############

sed -i 's/\(#define QLZ_COMPRESSION_LEVEL 1\)/\/\/\1/' $TARGET/quicklz.h
sed -i 's/\/\/\(#define QLZ_COMPRESSION_LEVEL 3\)/\1/' $TARGET/quicklz.h
sed -i 's/\/\/\(#define QLZ_MEMORY_SAFE\)/\1/' $TARGET/quicklz.h

# Compilation
#############

echo "$CC $CC_OPTS $LUA_CONF $BONALUNA_CONF -I. -I$TARGET bl.c -o $TARGET/$BL $CC_LIBS"
$CC $CC_OPTS $LUA_CONF $BONALUNA_CONF -I. -I$TARGET bl.c -o $TARGET/$BL $CC_LIBS || error "Compilation error"
STRIP=$(echo $CC | sed 's/gcc/strip/')
$STRIP $TARGET/$BL
cp $TARGET/$BL .

# Documentation and tests
#########################

./$BL bonaluna.lua || error "Non regression tests failed"
RST2HTML=$(which rst2html 2>/dev/null || which rst2html.py 2>/dev/null)
if [ -x "$RST2HTML" ]
then
    mkdir -p ../doc/lua
    cp -f $LUA_SRC/doc/* ../doc/lua/
    LANG=en $RST2HTML --section-numbering --language=en --cloak-email-addresses ../doc/bonaluna.rst > ../doc/bonaluna.html
fi
