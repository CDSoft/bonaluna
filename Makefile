# BonaLuna

BUILD = build.sh
DEPENDENCIES = Makefile VERSION src/$(BUILD) $(wildcard src/*.c) $(wildcard src/*.h) $(wildcard src/*.lua) $(wildcard tools/*.lua)

UNAME = $(shell uname)

ifneq "$(findstring Linux,$(UNAME))" ""

all: bl bl64 bl.exe

bl: $(DEPENDENCIES)
	cd src && $(BUILD) linux $@ gcc 32
	mv src/$@ $@

bl64: $(DEPENDENCIES)
	cd src && $(BUILD) linux64 $@ gcc 64
	mv src/$@ $@

bl.exe: $(DEPENDENCIES)
	cd src && $(BUILD) win32 $@ i586-mingw32msvc-gcc 32
	mv src/$@ $@

endif

ifneq "$(findstring MINGW32,$(UNAME))" ""

all: bl.exe

bl.exe: $(DEPENDENCIES)
	cd src && $(BUILD) win32 $@ gcc 32
	mv src/$@ $@

endif

clean:
	cd src && $(BUILD) --clean
	rm -f bl bl64 bl.exe
