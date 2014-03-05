# BonaLuna Makefile
#
# Copyright (C) 2010-2014 Christophe Delord
# http://cdsoft.fr/bl/bonaluna.html
#
# BonaLuna is based on Lua 5.2
# Copyright (C) 1994-2013 Lua.org, PUC-Rio
#
# Freely available under the terms of the Lua license.

BUILD = build.sh
DEPENDENCIES = Makefile VERSION setup src/$(BUILD) $(wildcard src/*.c) $(wildcard src/*.h) $(wildcard src/*.lua) $(wildcard tools/*.lua)

UNAME = $(shell uname)

ifneq "$(findstring Linux,$(UNAME))" ""

all: bl.exe bl

bl: $(DEPENDENCIES)
	. setup && cd src && $(BUILD) linux $@ gcc 32
	mv src/$@ $@

bl.exe: $(DEPENDENCIES)
	. setup && cd src && $(BUILD) win32 $@ i586-mingw32msvc-gcc 32
	mv src/$@ $@

endif

ifneq "$(findstring MINGW32,$(UNAME))" ""

all: bl.exe

bl.exe: $(DEPENDENCIES)
	. setup && cd src && $(BUILD) win32 $@ gcc 32
	mv src/$@ $@

endif

clean:
	cd src && $(BUILD) --clean
	rm -f bl bl.exe
