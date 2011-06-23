#!/bin/bash

# BonaLuna compilation script
#
# Copyright (C) 2010-2011 Christophe Delord
# http://cdsoft.fr/bl/bonaluna.html
#
# BonaLuna is based on Lua 5.2
# Copyright (C) 2010 Lua.org, PUC-Rio.
#
# Freely available under the terms of the Lua license.

LUA_SRC=lua-5.2.0-beta
LUA_URL=http://www.lua.org/work/$LUA_SRC-rc2.tar.gz

LZO_SRC=minilzo.205
LZO_URL=http://www.oberhumer.com/opensource/lzo/download/minilzo-2.05.tar.gz
QLZ_SRC=quicklz
QLZ_URL=http://www.quicklz.com/
LZ4_SRC="LZ4 - BSD"
LZ4_URL=http://lz4.googlecode.com/files/LZ4%20-%20BSD.zip
CURL_SRC=curl-7.21.6
CURL_URL=http://curl.haxx.se/download/$CURL_SRC.tar.gz

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
BUILD=build
TARGET=$BUILD/$1
BL=$2
CC=$3
BITS=$4

export CC
export AR=$(echo $CC | sed 's/gcc/ar/')
export STRIP=$(echo $CC | sed 's/gcc/strip/')
export RANLIB=$(echo $CC | sed 's/gcc/ranlib/')
export WINDRES=$(echo $CC | sed 's/gcc/windres/')

if $clean
then
    echo "Clean..."
    rm -rf $BUILD
    exit
fi

mkdir -p $BUILD

# Check configuration
#####################

for lib in LZO QLZ LZ4 CRYPT CURL
do
    eval USE_$lib=false
done
PEGAR_CONF+=" lua:stdlib.lua"
for lib in $LIBRARIES
do
    case "$lib" in
        QLZ|LZO|LZ4)    export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true;;
        CRYPT)          export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true; export PEGAR_CONF+=" lua:crypt.lua";;
        CURL)           export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true; export PEGAR_CONF+=" lua:curl.lua";;
        *)              echo "Unknown library: $lib"; exit 1;;
    esac
done

# Check parameters
##################

[ -x /usr/bin/$CC ] || error "Unknown compiler: $CC"
[ "$BITS" = "32" ] || [ "$BITS" = "64" ] || error "Wrong integer size (should be 32 or 64)"

CC_OPTS="-O2 -std=gnu99"
CC_LIBS2="-lm"
BONALUNA_CONF="-DBL_VERSION=\"$(cat ../VERSION)\"" 
CC_INC+=" -I. -I$TARGET"

case "$(uname)" in
    MINGW32*)   PLATFORM=Windows ;;
    *)          case "$CC" in
                    gcc)        PLATFORM=Linux ;;
                    *mingw32*)  PLATFORM=Windows ;;
                esac
                ;;
esac

case "$PLATFORM" in
    Linux)      LUA_CONF+=" -DLUA_USE_LINUX"
                CC_LIBS2+=" -ldl -lreadline -lrt"
                ;;
    Windows)    #LUA_CONF+=" -DLUA_BUILD_AS_DLL"
                CC_LIBS2+=" -lws2_32"
                ;;
esac

BONALUNA_CONF="$BONALUNA_CONF -DBONALUNA_PLATFORM=\"$PLATFORM\""

# Download Lua and library sources
##################################

[ -e $(basename $LUA_URL) ] || wget $LUA_URL
[ -e $LUA_SRC ] || tar xzf $(basename $LUA_URL)

$USE_LZO && (
    [ -e $(basename $LZO_URL) ] || wget $LZO_URL
    [ -e $LZO_SRC ] || tar xzf $(basename $LZO_URL)
)

$USE_QLZ && (
    mkdir -p $QLZ_SRC
    cd $QLZ_SRC
    [ -e $QLZ_SRC.c ] || wget $QLZ_URL/$QLZ_SRC.c
    [ -e $QLZ_SRC.h ] || wget $QLZ_URL/$QLZ_SRC.h
)

$USE_LZ4 && (
    [ -e "$LZ4_SRC".zip ] || wget $LZ4_URL
    [ -e "$LZ4_SRC" ] || unzip "$LZ4_SRC.zip"
)

$USE_CURL && (
    [ -e $(basename $CURL_URL) ] || wget $CURL_URL
    [ -e $CURL_SRC ] || tar xzf $(basename $CURL_URL)
)

# Target initialisation
#######################

mkdir -p $TARGET
cp -f $LUA_SRC/src/* $TARGET/
$USE_LZO && cp -f $LZO_SRC/*.{c,h} $TARGET/
$USE_QLZ && cp -f $QLZ_SRC/*.{c,h} $TARGET/
$USE_LZ4 && cp -f "$LZ4_SRC"/LZ4/lz4.{c,h} $TARGET/
$USE_CURL && ! [ -e $TARGET/$CURL_SRC ] && cp -rf $CURL_SRC $TARGET/

case "$PLATFORM" in
    Linux)      ;;
    Windows)    ;;
esac

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
        print "#if defined(USE_LZ)"
        print "  {LUA_LZLIBNAME, luaopen_lz},"
        print "#endif"
        print "#if defined(USE_CURL)"
        print "  {LUA_CURLLIBNAME, luaopen_cURL},"
        print "#endif"
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
[ $BITS = 64 ] && CC_LIBS+=" $TARGET/lbitlib64.c"

[ $BITS = 64 ] && awk '
    /LUA_BITLIBNAME/ {
        print "  {LUA_BITLIB64NAME,  luaopen_bit64},"
        }
    {print}
' $TARGET/linit.c > /tmp/linit.c
[ $BITS = 64 ] && mv /tmp/linit.c $TARGET/linit.c

# LZO patches
#############

$USE_LZO && (
    sed -i 's/__LZO_IN_MINLZO/__LZO_IN_MINILZO/g' $TARGET/minilzo.c
)

# QLZ patches
#############

$USE_QLZ && (
    sed -i 's/\(#define QLZ_COMPRESSION_LEVEL 1\)/\/\/\1/' $TARGET/quicklz.h
    sed -i 's/\/\/\(#define QLZ_COMPRESSION_LEVEL 3\)/\1/' $TARGET/quicklz.h
    sed -i 's/\/\/\(#define QLZ_MEMORY_SAFE\)/\1/' $TARGET/quicklz.h
)

# LZ4 patches
#############

$USE_LZ4 && (
    sed -i 's/\/\/ *\(#define SAFEWRITEBUFFER\)/\1/' $TARGET/lz4.h
)

# Luacurl patches
#################

#$USE_CURL && (
#    sed -i 's/lua_strlen/lua_rawlen/g' $TARGET/luacurl.c
#    sed -i 's/luaL_reg/luaL_Reg/g' $TARGET/luacurl.c
#    sed -i 's/createmeta/luacurl_createmeta/g' $TARGET/luacurl.c
#    sed -i 's/luaL_openlib (L, 0, luacurl_meths, 0)/luaL_setfuncs(L, luacurl_meths, 0)/' $TARGET/luacurl.c
#    sed -i 's/luaL_openlib (L, LUACURL_LIBNAME, luacurl_funcs, 0)/luaL_newlib(L, luacurl_funcs)/' $TARGET/luacurl.c
#    sed -i 's/free_slist(L, key)/\/\/free_slist(L, key)/' $TARGET/luacurl.c
#)

# External libraries
####################

export EXTLIBS=`pwd`/$TARGET
export INCLUDE_PATH=$EXTLIBS/include
export LIBRARY_PATH=$EXTLIBS/lib
mkdir -p $INCLUDE_PATH $LIBRARY_PATH
CC_INC+=" -I$INCLUDE_PATH"
CC_LIBS+=" -L$LIBRARY_PATH"

# cURL configuration
####################

case $PLATFORM in
    Linux)      LIB_CURL=$TARGET/$CURL_SRC/lib/.libs/libcurl.a ;;
    Windows)    LIB_CURL=$TARGET/$CURL_SRC/lib/libcurl.a ;;
esac
$USE_CURL && ! [ -e $LIB_CURL ] && (
    cd $TARGET/$CURL_SRC
    CURL_CONF="--without-ldap-lib --without-zlib --without-ssl
        --enable-http
        --enable-ftp
        --enable-file
        --disable-ldap
        --disable-ldaps
        --enable-rtsp
        --enable-proxy
        --enable-dict
        --enable-telnet
        --enable-tftp
        --enable-pop3
        --enable-imap
        --enable-smtp
        --disable-gopher
        --disable-manual
        --enable-ipv6
        --enable-verbose
        --disable-sspi
        --disable-crypto-auth
        --disable-tls-srp
        --enable-cookies
    "
    case $PLATFORM in
        Linux)      ./configure --disable-shared $CURL_CONF && (
                        cd lib && make
                    );;
        Windows)    ./configure --disable-shared $CURL_CONF && (
                        sed -i "s/CC =.*/CC = $CC/" lib/Makefile.m32
                        sed -i "s/AR =.*/AR = $AR/" lib/Makefile.m32
                        sed -i "s/RANLIB =.*/RANLIB = $RANLIB/" lib/Makefile.m32
                        sed -i "s/RC =.*/RC = $WINDRES/" lib/Makefile.m32
                        sed -i "s/STRIP =.*/STRIP = $STRIP -g/" lib/Makefile.m32
                        cd lib && make -f Makefile.m32
                    );;
    esac
)
$USE_CURL && cp -f $LIB_CURL $LIBRARY_PATH/
$USE_CURL && cp -rf $TARGET/$CURL_SRC/include/curl $INCLUDE_PATH/
$USE_CURL && CC_LIBS="$LIBRARY_PATH/libcurl.a $CC_LIBS"
case $PLATFORM in
    Linux)      CC_LIBS2+="" ;;
    Windows)    BONALUNA_CONF+=" -DCURL_STATICLIB"
                CC_LIBS2+=" -lwldap32" ;;
esac

# Compilation
#############

if [ "$PLATFORM" = "Windows" ] && [ -e "$ICON" ]
then
    echo "100 ICON DISCARDABLE \"$ICON\"" > icon.rc
    $WINDRES -i icon.rc -o icon.o
    CC_LIBS+=" icon.o"
fi
echo "$CC $CC_OPTS $LUA_CONF $BONALUNA_CONF $CC_INC bl.c -o $TARGET/$BL $CC_LIBS $CC_LIBS2"
$CC -g $CC_OPTS $LUA_CONF $BONALUNA_CONF $CC_INC bl.c -o $TARGET/$BL $CC_LIBS $CC_LIBS2 || error "Compilation error"
$STRIP $TARGET/$BL
[ -n "$COMPRESS" ] && $COMPRESS $TARGET/$BL
$TARGET/$BL ../tools/pegar.lua read:$TARGET/$BL $PEGAR_CONF write:$BL
#cp $TARGET/$BL .

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
