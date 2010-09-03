# BonaLuna
#
# Copyright (C) 2010 Christophe Delord
# http://cdsoft.fr/bonaluna.html
#
# BonaLuna is based on Lua 5.2 work 4
# Copyright (C) 2010 Lua.org, PUC-Rio.
#
# Freely available under the terms of the Lua license.

VERSION = 0.2

LUA_SRC = lua-5.2.0-work4
LUA_URL = http://www.lua.org/work/$(LUA_SRC).tar.gz

PATCH = patch
BONALUNA_PATCH = $(PATCH)/linit.c $(PATCH)/lua.c $(PATCH)/lvm.c $(PATCH)/lparser.c
BONALUNA_SRC = bonaluna.c bonaluna.h bl.c

CC_OPTS = -O3 -std=gnu99
CC_LIBS = -lm

LUA_CONF =
BONALUNA_CONF = -DVERSION=\"$(VERSION)\"

UNAME=$(shell uname)

ifneq "$(findstring Linux,$(UNAME))" ""
PLATFORM = Linux
BL       = bl
LUA_CONF += -DLUA_USE_POSIX -DLUA_USE_DLOPEN -DLUA_USE_READLINE
CC_LIBS  += -ldl -lreadline
DOC      = bonaluna.html
endif
ifneq "$(findstring MINGW32,$(UNAME))" ""
PLATFORM = Windows
BL       = bl.exe
CC_LIBS  += -lws2_32
endif

ifneq "$(PLATFORM)" ""
$(info **************************)
$(info * BonaLuna for $(PLATFORM))
$(info **************************)
BONALUNA_CONF += -DBONALUNA_PLATFORM=\"$(PLATFORM)\"
else
$(error Unknown platform: $(UNAME))
endif

all: $(BL) $(DOC)

clean:
	rm -f $(BL)
	rm -rf $(LUA_SRC) $(PATCH)

$(LUA_SRC): $(notdir $(LUA_URL))
	tar xzf $<
	touch $@

$(notdir $(LUA_URL)):
	wget $(LUA_URL) -O $@

$(BL): $(LUA_SRC) $(BONALUNA_PATCH) $(BONALUNA_SRC)
	gcc $(CC_OPTS) $(LUA_CONF) $(BONALUNA_CONF) \
		-I. -I$(PATCH) \
		-I$(LUA_SRC)/include \
		-I$(LUA_SRC)/src \
		bl.c -o $@ \
		$(CC_LIBS)
	strip $@

$(PATCH)/lua.c: $(LUA_SRC)/src/lua.c
	mkdir -p $(dir $@)
	awk '                                                  \
		/LUA_COPYRIGHT/ {                                  \
			print "printf(\"%s\\n\", BONALUNA_COPYRIGHT);" \
		}                                                  \
		{print}                                            \
	' $< > $@

$(PATCH)/one.c: $(LUA_SRC)/etc/one.c
	mkdir -p $(dir $@)
	cp $< $@
	echo "" >> $@
	echo "/* BonaLuna libraries */" >> $@
	echo "#include \"bonaluna.c\"" >> $@

$(PATCH)/linit.c: $(LUA_SRC)/src/linit.c
	mkdir -p $(dir $@)
	awk '                                            \
		/lauxlib.h/ {                                \
			print "#include \"bonaluna.h\""          \
		}                                            \
		/LUA_MATHLIBNAME/ {                          \
			print "  {LUA_FSLIBNAME,  luaopen_fs},"; \
			print "  {LUA_PSLIBNAME,  luaopen_ps},"; \
			print "  {LUA_SYSLIBNAME, luaopen_sys}," \
			}                                        \
		{print}                                      \
	' $< > $@

$(PATCH)/lvm.c: $(LUA_SRC)/src/lvm.c
	mkdir -p $(dir $@)
	sed 's/pushclosure/lvm_pushclosure/g' $< > $@

$(PATCH)/lparser.c: $(LUA_SRC)/src/lparser.c
	mkdir -p $(dir $@)
	sed 's/pushclosure/lparser_pushclosure/g' $< > $@

bonaluna.html: $(BL) bonaluna.lua
	$(BL) bonaluna.lua
	LANG=en rst2html --section-numbering --language=en --cloak-email-addresses bonaluna.rst > $@

