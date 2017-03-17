# BonaLuna Makefile
#
# Copyright (C) 2010-2017 Christophe Delord
# http://cdsoft.fr/bl/bonaluna.html
#
# BonaLuna is based on Lua 5.3
# Copyright (C) 1994-2017 Lua.org, PUC-Rio
#
# Freely available under the terms of the MIT license.

BUILD = build.sh
DEPENDENCIES = Makefile VERSION setup src/$(BUILD) $(wildcard src/*.c) $(wildcard src/*.h) $(wildcard src/*.lua) $(wildcard tools/*.lua)

UNAME = $(shell uname)

ifneq "$(findstring Linux,$(UNAME))" ""

all: bl.exe bl

bl: $(DEPENDENCIES)
	. ./setup && cd src && ./$(BUILD) linux $@ gcc 32
	mv src/$@ $@

bl.exe: $(DEPENDENCIES)
	. ./setup && cd src && ./$(BUILD) win32 $@ x86_64-w64-mingw32-gcc 32
	mv src/$@ $@

endif

ifneq "$(findstring MINGW32,$(UNAME))" ""

all: bl.exe

bl.exe: $(DEPENDENCIES)
	. ./setup && cd src && ./$(BUILD) win32 $@ gcc 32
	mv src/$@ $@

endif

clean:
	cd src && ./$(BUILD) --clean
	rm -f bl bl.exe
