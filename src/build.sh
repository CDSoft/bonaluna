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

LUA_SRC=lua-5.2.2
LUA_URL=http://www.lua.org/ftp/$LUA_SRC.tar.gz

LZO_SRC=lzo-2.06
LZO_URL=http://www.oberhumer.com/opensource/lzo/download/$LZO_SRC.tar.gz
QLZ_SRC=quicklz
QLZ_URL=http://www.quicklz.com/
LZ4_SRC="LZ4 - BSD"
LZ4_URL=http://lz4.googlecode.com/files/LZ4%20-%20BSD.zip
ZLIB_SRC=zlib-1.2.6
ZLIB_URL=http://zlib.net/$ZLIB_SRC.tar.bz2
UCL_SRC=ucl-1.03
UCL_URL=http://www.oberhumer.com/opensource/ucl/download/$UCL_SRC.tar.gz
LZMA_SRC=xz-5.0.3
LZMA_URL=http://tukaani.org/xz/$LZMA_SRC.tar.gz
CURL_SRC=curl-7.23.1
CURL_URL=http://curl.haxx.se/download/$CURL_SRC.tar.gz
SOCKET_SRC=luasocket-2.0.2
SOCKET_URL=http://luaforge.net/frs/download.php/2664/$SOCKET_SRC.tar.gz

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

for lib in LZO MINILZO UCL QLZ LZ4 LZMA ZLIB CRYPT CURL SOCKET
do
    eval USE_$lib=false
done
PEGAR_CONF+=" lua:stdlib.lua"
for lib in $LIBRARIES
do
    case "$lib" in
        LZO|MINILZO|UCL)    export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true;;
        QLZ|LZ4|ZLIB|LZMA)  export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true;;
        CRYPT)              export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true; export PEGAR_CONF+=" lua:crypt.lua";;
        CURL)               export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true; export PEGAR_CONF+=" lua:curl.lua";;
        SOCKET)             export LUA_CONF+=" -DUSE_$lib"; eval USE_$lib=true;
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/ltn12.lua=$TARGET/ltn12.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/mime.lua=$TARGET/mime.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/socket.lua=$TARGET/socket.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/url.lua=$TARGET/url.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/tp.lua=$TARGET/tp.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/smtp.lua=$TARGET/smtp.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/ftp.lua=$TARGET/ftp.lua"
                            export PEGAR_CONF+=" lua:$SOCKET_SRC/http.lua=$TARGET/http.lua"
                            export PEGAR_CONF+=" lua:ftp.lua"
                            ;;
        *)                  echo "Unknown library: $lib"; exit 1;;
    esac
done

$USE_LZO && $USE_MINILZO && {
    echo "Can not use both LZO and miniLZO"
    exit 1
}

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
    Windows)    #LUA_CONF+=" -DLUA_USE_LONGLONG"
                CC_LIBS2+=" -lws2_32 -ladvapi32"
                ;;
esac

BONALUNA_CONF="$BONALUNA_CONF -DBONALUNA_PLATFORM=\"$PLATFORM\""

# Download Lua and library sources
##################################

[ -e $(basename $LUA_URL) ] || wget $LUA_URL
[ -e $LUA_SRC ] || tar xzf $(basename $LUA_URL)

( $USE_LZO || $USE_MINILZO ) && (
    [ -e $(basename $LZO_URL) ] || wget $LZO_URL
    [ -e $LZO_SRC ] || tar xzf $(basename $LZO_URL)
)

$USE_UCL && (
    [ -e $(basename $UCL_URL) ] || wget $UCL_URL
    [ -e $UCL_SRC ] || tar xzf $(basename $UCL_URL)
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

$USE_LZMA && (
    [ -e $(basename $LZMA_URL) ] || wget $LZMA_URL
    [ -e $LZMA_SRC ] || tar xzf $(basename $LZMA_URL)
)

$USE_ZLIB && (
    [ -e $(basename $ZLIB_URL) ] || wget $ZLIB_URL
    [ -e $ZLIB_SRC ] || tar xjf $(basename $ZLIB_URL)
)

$USE_CURL && (
    [ -e $(basename $CURL_URL) ] || wget $CURL_URL
    [ -e $CURL_SRC ] || tar xzf $(basename $CURL_URL)
)

$USE_SOCKET && (
    [ -e $(basename $SOCKET_URL) ] || wget $SOCKET_URL
    [ -e $SOCKET_SRC ] || tar xzf $(basename $SOCKET_URL)
)

# Target initialisation
#######################

mkdir -p $TARGET
cp -f $LUA_SRC/src/* $TARGET/
( $USE_LZO || $USE_MINILZO ) && {
    ! [ -e $TARGET/$LZO_SRC ] && cp -rf $LZO_SRC $TARGET/
    cp -f $TARGET/$LZO_SRC/minilzo/*.{c,h} $TARGET/
    cp -f $TARGET/$LZO_SRC/include/lzo/*.h $TARGET/
}
$USE_QLZ && cp -f $QLZ_SRC/*.{c,h} $TARGET/
$USE_LZ4 && cp -f "$LZ4_SRC"/LZ4/lz4.{c,h} $TARGET/
$USE_ZLIB && ! [ -e $TARGET/$ZLIB_SRC ] && cp -rf $ZLIB_SRC $TARGET/
$USE_UCL && ! [ -e $TARGET/$UCL_SRC ] && cp -rf $UCL_SRC $TARGET/
$USE_LZMA && ! [ -e $TARGET/$LZMA_SRC ] && cp -rf $LZMA_SRC $TARGET/
$USE_CURL && ! [ -e $TARGET/$CURL_SRC ] && cp -rf $CURL_SRC $TARGET/
$USE_SOCKET && cp -f $SOCKET_SRC/src/*.{c,h,lua} $TARGET/

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
    /runargs\(L/ {
        print "if (!glue(L, argv)) return 0;"
        print
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
        print "#if defined(USE_Z)"
        print "  {LUA_ZLIBNAME, luaopen_z},"
        print "#endif"
        print "#if defined(USE_LZO)"
        print "  {LUA_LZOLIBNAME, luaopen_lzo},"
        print "#endif"
        print "#if defined(USE_MINILZO)"
        print "  {LUA_MINILZOLIBNAME, luaopen_minilzo},"
        print "#endif"
        print "#if defined(USE_QLZ)"
        print "  {LUA_QLZLIBNAME, luaopen_qlz},"
        print "#endif"
        print "#if defined(USE_LZ4)"
        print "  {LUA_LZ4LIBNAME, luaopen_lz4},"
        print "#endif"
        print "#if defined(USE_ZLIB)"
        print "  {LUA_ZLIBLIBNAME, luaopen_zlib},"
        print "#endif"
        print "#if defined(USE_UCL)"
        print "  {LUA_UCLLIBNAME, luaopen_ucl},"
        print "#endif"
        print "#if defined(USE_LZMA)"
        print "  {LUA_LZMALIBNAME, luaopen_lzma},"
        print "#endif"
        print "#if defined(USE_CURL)"
        print "  {LUA_CURLLIBNAME, luaopen_cURL},"
        print "#endif"
        print "#if defined(USE_CRYPT)"
        print "  {LUA_CRYPTLIBNAME, luaopen_crypt},"
        print "#endif"
        print "#if defined(USE_SOCKET)"
        print "  {LUA_SOCKETLIBNAME, luaopen_socket_core},"
        print "  {LUA_MIMELIBNAME, luaopen_mime_core},"
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

$USE_MINILZO && (
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

# Lua Socket patches
####################

$USE_SOCKET && (

    sed -i 's/luaL_reg/luaL_Reg/g' $TARGET/{auxiliar,except,inet,luasocket,mime,select,tcp,timeout,udp}.{c,h}
    sed -i 's/luaL_typerror/typeerror/g' $TARGET/{auxiliar,options}.{c,h}
    sed -i 's/luaL_putchar/luaL_addchar/g' $TARGET/{buffer,mime}.{c,h}
    sed -i 's/luaL_openlib(L, NULL, func, 0)/luaL_setfuncs(L, func, 0)/' $TARGET/{except,inet,select,tcp,timeout,udp}.c
    sed -i 's/luaL_openlib(L, "mime", func, 0)/luaL_newlib(L, func)/' $TARGET/mime.c
    sed -i 's/luaL_openlib(L, "socket", func, 0)/luaL_newlib(L, func)/' $TARGET/luasocket.c

    sed -i 's/\<func\>/except_func/' $TARGET/except.c
    sed -i 's/\<func\>/inet_func/' $TARGET/inet.c
    #sed -i 's/\<func\>/luasocket_func/' $TARGET/luasocket.c
    sed -i 's/\<func\>/mime_func/' $TARGET/mime.c
    sed -i 's/\<func\>/select_func/' $TARGET/select.c
    sed -i 's/\<func\>/tcp_func/' $TARGET/tcp.c
    sed -i 's/\<func\>/timeout_func/' $TARGET/timeout.c
    sed -i 's/\<func\>/udp_func/' $TARGET/udp.c

    sed -i 's/\<opt\>/tcp_opt/' $TARGET/tcp.c
    sed -i 's/\<opt\>/udp_opt/' $TARGET/udp.c
    sed -i 's/\<meth_/tcp_meth_/' $TARGET/tcp.c
    sed -i 's/\<meth_/udp_meth_/' $TARGET/udp.c
    sed -i 's/\<global_create\>/tcp_global_create/' $TARGET/tcp.c
    sed -i 's/\<global_create\>/udp_global_create/' $TARGET/udp.c

    mv -f $TARGET/io.h $TARGET/lsio.h
    mv -f $TARGET/io.c $TARGET/lsio.c
    sed -i 's/\<io\.h\>/lsio.h/' $TARGET/{auxiliar,except,inet,lsio,timeout}.c
    sed -i 's/\<io\.h\>/lsio.h/' $TARGET/{buffer,lsio,socket}.h

    # ltn12.lua
    sed -i \
        -e 's/module("ltn12")/ltn12 = {}; local _ENV = ltn12/' \
        $TARGET/ltn12.lua

    # mime.lua
    sed -i \
        -e 's/require("ltn12")/ltn12/' \
        -e 's/require("mime.core")/mime/' \
        -e 's/module("mime")/local _ENV = mime/' \
        $TARGET/mime.lua

    # socket.lua
    sed -i \
        -e 's/require("socket.core")/socket/' \
        -e 's/module("socket")/local _ENV = socket/' \
        $TARGET/socket.lua

    # url.lua
    sed -i \
        -e 's/module("socket.url")/socket.url = {}; local _ENV = socket.url/' \
        $TARGET/url.lua

    # tp.lua
    sed -i \
        -e 's/require("socket")/socket/' \
        -e 's/require("ltn12")/ltn12/' \
        -e 's/module("socket.tp")/socket.tp = {}; local _ENV = socket.tp/' \
        $TARGET/tp.lua

    # smtp.lua
    sed -i \
        -e 's/require("socket")/socket/' \
        -e 's/require("socket.tp")/socket.tp/' \
        -e 's/require("ltn12")/ltn12/' \
        -e 's/require("mime")/mime/' \
        -e 's/module("socket.smtp")/socket.smtp = {}; local _ENV = socket.smtp/' \
        $TARGET/smtp.lua

    # ftp.lua
    sed -i \
        -e 's/require("socket")/socket/' \
        -e 's/require("socket.url")/socket.url/' \
        -e 's/require("socket.tp")/socket.tp/' \
        -e 's/require("ltn12")/ltn12/' \
        -e 's/module("socket.ftp")/socket.ftp = {}; local _ENV = socket.ftp/' \
        $TARGET/ftp.lua

    # http.lua
    sed -i \
        -e 's/require("socket")/socket/' \
        -e 's/require("socket.url")/socket.url/' \
        -e 's/require("mime")/mime/' \
        -e 's/require("ltn12")/ltn12/' \
        -e 's/module("socket.http")/socket.http = {}; local _ENV = socket.http/' \
        $TARGET/http.lua

)

# External libraries
####################

export EXTLIBS=`pwd`/$TARGET
export INCLUDE_PATH=$EXTLIBS/include
export LIBRARY_PATH=$EXTLIBS/lib
mkdir -p $INCLUDE_PATH $LIBRARY_PATH
CC_INC+=" -I$INCLUDE_PATH"
CC_LIBS+=" -L$LIBRARY_PATH"

# LZO configuration
###################

LIB_LZO=$TARGET/$LZO_SRC/src/.libs/liblzo2.a
$USE_LZO && ! [ -e $LIB_LZO ] && (
    cd $TARGET/$LZO_SRC
    ./configure && make
)
$USE_LZO && cp -f $LIB_LZO $LIBRARY_PATH/
$USE_LZO && cp -f $TARGET/$LZO_SRC/include/lzo/*.h $INCLUDE_PATH/
$USE_MINILZO && cp -f $TARGET/$LZO_SRC/include/lzo/*.h $INCLUDE_PATH/
$USE_LZO && CC_LIBS2+=" $LIBRARY_PATH/liblzo2.a"

# zlib configuration
####################

LIB_ZLIB=$TARGET/$ZLIB_SRC/libz.a
$USE_ZLIB && ! [ -e $LIB_ZLIB ] && (
    cd $TARGET/$ZLIB_SRC
    case $PLATFORM in
        Linux)      ./configure && make ;;
        Windows)    sed -i "s/PREFIX =/PREFIX = ${CC/gcc}/" win32/Makefile.gcc
                    make -f win32/Makefile.gcc ;;
    esac
)
$USE_ZLIB && cp -f $LIB_ZLIB $LIBRARY_PATH/
$USE_ZLIB && cp -f $TARGET/$ZLIB_SRC/{zlib.h,zconf.h} $INCLUDE_PATH/
$USE_ZLIB && CC_LIBS2+=" $LIBRARY_PATH/libz.a"
$USE_ZLIB && LUA_CONF+=" -DZLIB_LEVEL=9"

# UCL configuration
###################

LIB_UCL=$TARGET/$UCL_SRC/src/.libs/libucl.a
$USE_UCL && ! [ -e $LIB_UCL ] && (
    cd $TARGET/$UCL_SRC
    case $PLATFORM in
        Linux)      ./configure && make ;;
        Windows)    ./configure LIBS=-lwinmm && make ;;
    esac
)
$USE_UCL && cp -f $LIB_UCL $LIBRARY_PATH/
$USE_UCL && cp -f $TARGET/$UCL_SRC/include/ucl/{ucl.h,uclconf.h} $INCLUDE_PATH/
$USE_UCL && sed -i 's#ucl/uclconf.h#uclconf.h#' $INCLUDE_PATH/ucl.h
$USE_UCL && CC_LIBS2+=" $LIBRARY_PATH/libucl.a"
$USE_UCL && LUA_CONF+=" -DUCL_LEVEL=6"

# LZMA configuration
####################

LIB_LZMA=$TARGET/$LZMA_SRC/src/liblzma/.libs/liblzma.a
$USE_LZMA && ! [ -e $LIB_LZMA ] && (
    cd $TARGET/$LZMA_SRC
    ./configure --disable-shared && (cd src/liblzma && make)
)
$USE_LZMA && cp -f $LIB_LZMA $LIBRARY_PATH/
$USE_LZMA && cp -f $TARGET/$LZMA_SRC/src/liblzma/api/*.h $INCLUDE_PATH/
$USE_LZMA && mkdir -p $INCLUDE_PATH/lzma/
$USE_LZMA && cp -f $TARGET/$LZMA_SRC/src/liblzma/api/lzma/*.h $INCLUDE_PATH/lzma/
$USE_LZMA && CC_LIBS2+=" $LIBRARY_PATH/liblzma.a"
$USE_LZMA && LUA_CONF+=" -DLZMA_LEVEL=6"

# cURL configuration
####################

case $PLATFORM in
    Linux)      LIB_CURL=$TARGET/$CURL_SRC/lib/.libs/libcurl.a ;;
    Windows)    LIB_CURL=$TARGET/$CURL_SRC/lib/libcurl.a ;;
esac
$USE_CURL && ! [ -e $LIB_CURL ] && (
    cd $TARGET/$CURL_SRC
    CURL_CONF="--without-ldap-lib --without-ssl
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
    $USE_ZLIB && CURL_CONF+=" --with-zlib=$EXTLIBS"
    ! $USE_ZLIB && CURL_CONF+=" --without-zlib"
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
[ -n "$COMPRESS" ] && $COMPRESS $TARGET/$BL && chmod +x $TARGET/$BL
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
    sed -i 's/<head>/<head><link rel="icon" href="bl.png"\/>/i' ../doc/bonaluna.html
    sed -i 's/<title>logo /<title>/' ../doc/bonaluna.html
    cp bl.png ../doc/
fi
