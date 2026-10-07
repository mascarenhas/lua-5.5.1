# Makefile for installing Lua
# See doc/readme.html for installation and customization instructions.

# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

# Your platform. See PLATS for possible values.
PLAT= guess

# Where to install. The installation starts in the src and doc directories,
# so take care if INSTALL_TOP is not an absolute path. See the local target.
# You may want to make INSTALL_LMOD and INSTALL_CMOD consistent with
# LUA_ROOT, LUA_LDIR, and LUA_CDIR in luaconf.h.
INSTALL_TOP= $(PREFIX)

# How to install. If your install program does not support "-p", then
# you may have to run ranlib on the installed liblua.a.
# MSYS shells use Unix utilities; native Windows shells use built-ins.
ifeq ($(OS),Windows_NT)
# Native GNU Make defaults to sh.exe even when it falls back to cmd.exe.
ifeq ($(SHELL),sh.exe)
ifneq ($(origin SHELL),command line)
	INSTALL_NATIVE_WINDOWS= yes
endif
else ifeq ($(findstring sh,$(notdir $(SHELL))),)
	INSTALL_NATIVE_WINDOWS= yes
endif
endif

ifeq ($(INSTALL_NATIVE_WINDOWS),yes)
	INSTALL_TOP= $(subst /,\,$(PREFIX))
	INSTALL_BIN= $(INSTALL_TOP)\bin
	INSTALL_INC= $(INSTALL_TOP)\include
	INSTALL_LIB= $(INSTALL_TOP)\lib
	INSTALL_SRC= $(INSTALL_TOP)\src\lua-$R
	INSTALL_MAN= $(INSTALL_TOP)\man\man1
	INSTALL_LMOD= $(INSTALL_TOP)\share\lua\$V
	INSTALL_CMOD= $(INSTALL_TOP)\lib\lua\$V
	INSTALL_TMOD= $(INSTALL_TOP)\lib\titan\$(TITAN_LIBRARY_VERSION)

    INSTALL= copy /Y
    INSTALL_EXEC= $(INSTALL)
	INSTALL_DATA= $(INSTALL)
else
	INSTALL_BIN= $(INSTALL_TOP)/bin
	INSTALL_INC= $(INSTALL_TOP)/include
	INSTALL_LIB= $(INSTALL_TOP)/lib
	INSTALL_SRC= $(INSTALL_TOP)/src/lua-$R
	INSTALL_MAN= $(INSTALL_TOP)/man/man1
	INSTALL_LMOD= $(INSTALL_TOP)/share/lua/$V
	INSTALL_CMOD= $(INSTALL_TOP)/lib/lua/$V
	INSTALL_TMOD= $(INSTALL_TOP)/lib/titan/$(TITAN_LIBRARY_VERSION)

	INSTALL= install -p
	INSTALL_EXEC= $(INSTALL) -m 0755
	INSTALL_DATA= $(INSTALL) -m 0644
endif

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

# Convenience platforms targets.
PLATS= guess aix bsd c89 freebsd generic ios linux linux-readline macosx mingw posix solaris

# What to install.
ifeq ($(OS),Windows_NT)
	TO_BIN= lua.exe luac.exe lua55.dll
	TO_LIB= liblua55.a
else
	TO_BIN= lua luac
	TO_LIB= liblua.a
endif

TO_INC= lua.h luaconf.h lualib.h lauxlib.h lua.hpp
TO_SRC= *.c *.h
TO_MAN= lua.1 luac.1

# Lua version and release.
V= 5.5
R= $V.1

# Targets start here.
all:	$(PLAT)

$(PLATS) help test clean:
	@cd src && $(MAKE) $@

check-prefix: dummy
	$(if $(PREFIX),,$(error Error: PREFIX environment variable is required))

check-titan: dummy
	$(if $(TITAN_LIBRARY_VERSION),,$(error Error: TITAN_LIBRARY_VERSION environment variable is required))

ifeq ($(INSTALL_NATIVE_WINDOWS),yes)
install: SHELL= cmd.exe
install: .SHELLFLAGS= /c
endif

install: check-prefix check-titan
ifeq ($(INSTALL_NATIVE_WINDOWS),yes)
	@if not exist "$(INSTALL_BIN)" mkdir "$(INSTALL_BIN)"
	@if not exist "$(INSTALL_INC)" mkdir "$(INSTALL_INC)"
	@if not exist "$(INSTALL_LIB)" mkdir "$(INSTALL_LIB)"
	@if not exist "$(INSTALL_SRC)" mkdir "$(INSTALL_SRC)"
	@if not exist "$(INSTALL_MAN)" mkdir "$(INSTALL_MAN)"
	@if not exist "$(INSTALL_LMOD)" mkdir "$(INSTALL_LMOD)"
	@if not exist "$(INSTALL_CMOD)" mkdir "$(INSTALL_CMOD)"
	@if not exist "$(INSTALL_TMOD)" mkdir "$(INSTALL_TMOD)"
	@cd src && for %%F in ($(TO_BIN)) do @$(INSTALL_EXEC) "%%F" "$(INSTALL_BIN)" >nul || exit /b 1
	@cd src && for %%F in ($(TO_INC)) do @$(INSTALL_DATA) "%%F" "$(INSTALL_INC)" >nul || exit /b 1
	@cd src && for %%F in ($(TO_LIB)) do @$(INSTALL_DATA) "%%F" "$(INSTALL_LIB)" >nul || exit /b 1
	@cd src && for %%F in ($(TO_SRC)) do @$(INSTALL_DATA) "%%F" "$(INSTALL_SRC)" >nul || exit /b 1
	@cd doc && for %%F in ($(TO_MAN)) do @$(INSTALL_DATA) "%%F" "$(INSTALL_MAN)" >nul || exit /b 1
else
	@mkdir -p $(INSTALL_BIN) $(INSTALL_INC) $(INSTALL_LIB) $(INSTALL_SRC) $(INSTALL_MAN) $(INSTALL_LMOD) $(INSTALL_CMOD) $(INSTALL_TMOD)
	cd src && $(INSTALL_EXEC) $(TO_BIN) $(INSTALL_BIN)
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
	cd src && $(INSTALL_DATA) $(TO_SRC) $(INSTALL_SRC)
	cd doc && $(INSTALL_DATA) $(TO_MAN) $(INSTALL_MAN)
endif

# make may get confused with install/ if it does not support .PHONY.
dummy:

# Echo config parameters.
echo:
	@cd src && $(MAKE) -s echo
	@echo "PLAT= $(PLAT)"
	@echo "V= $V"
	@echo "R= $R"
	@echo "TO_BIN= $(TO_BIN)"
	@echo "TO_INC= $(TO_INC)"
	@echo "TO_LIB= $(TO_LIB)"
	@echo "TO_MAN= $(TO_MAN)"
	@echo "INSTALL_TOP= $(INSTALL_TOP)"
	@echo "INSTALL_BIN= $(INSTALL_BIN)"
	@echo "INSTALL_INC= $(INSTALL_INC)"
	@echo "INSTALL_LIB= $(INSTALL_LIB)"
	@echo "INSTALL_MAN= $(INSTALL_MAN)"
	@echo "INSTALL_LMOD= $(INSTALL_LMOD)"
	@echo "INSTALL_CMOD= $(INSTALL_CMOD)"
	@echo "INSTALL_EXEC= $(INSTALL_EXEC)"
	@echo "INSTALL_DATA= $(INSTALL_DATA)"

# Echo pkg-config data.
pc:
	@echo "version=$R"
	@echo "prefix=$(INSTALL_TOP)"
	@echo "libdir=$(INSTALL_LIB)"
	@echo "includedir=$(INSTALL_INC)"

# Targets that do not create files (not all makes understand .PHONY).
.PHONY: all $(PLATS) help test clean install uninstall local dummy echo pc check-prefix check-titan

# (end of Makefile)
