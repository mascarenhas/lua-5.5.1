# Makefile for building Lua
# See ../doc/readme.html for installation and customization instructions.

# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

# Your platform. See PLATS for possible values.
PLAT= guess

CC= gcc -std=gnu99
CFLAGS= -O2 -Wall -Wextra $(SYSCFLAGS) $(MYCFLAGS)
LDFLAGS= $(SYSLDFLAGS) $(MYLDFLAGS)
LIBS= -lm $(SYSLIBS) $(MYLIBS)

AR= ar rcu
RANLIB= ranlib
RM= rm -f
UNAME= uname

SYSCFLAGS=
SYSLDFLAGS=
SYSLIBS=

# The Unix platform targets below build position-independent objects so a host
# can link liblua.a into a shared library. It lives in SYSCFLAGS, ahead of the
# caller-owned tail of CFLAGS, so an ordinary MYCFLAGS cannot drop it.
UNIX_SYSCFLAGS= -fPIC

MYCFLAGS=
MYLDFLAGS=
MYLIBS=
MYOBJS=
# Additional interpreter-only objects (for example, a Windows resource).
MYLUAOBJS=
MYDLLFLAGS=
# Empty disables mingw's default link-time and post-link stripping.
MINGW_STRIP= yes
# Optional GNU import library emitted by the mingw DLL link.
LUA_IMPLIB=

# Special flags for compiler modules; -Os reduces code size.
CMCFLAGS= 

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

PLATS= guess aix bsd c89 freebsd generic ios linux linux-readline macosx mingw posix solaris

LUA_A=	liblua.a
LUA_LINK= $(LUA_A)
LUA_IMPLIBFLAGS=
ifneq ($(LUA_IMPLIB),)
LUA_LINK= $(LUA_IMPLIB)
LUA_IMPLIBFLAGS= -Wl,--out-implib,$(LUA_IMPLIB)
endif
CORE_O=	lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o lundump.o lvm.o lzio.o
LIB_O=	lauxlib.o lbaselib.o lcorolib.o ldblib.o liolib.o lmathlib.o loadlib.o loslib.o lstrlib.o ltablib.o lutf8lib.o linit.o
BASE_O= $(CORE_O) $(LIB_O) $(MYOBJS)

LUA_T=	lua
LUA_O=	lua.o

LUAC_T=	luac
LUAC_O=	luac.o

ALL_O= $(BASE_O) $(LUA_O) $(LUAC_O) $(MYLUAOBJS)
ALL_T= $(LUA_A) $(LUA_IMPLIB) $(LUA_T) $(LUAC_T)
ALL_A= $(LUA_A) $(LUA_IMPLIB)

# == Browser (WebAssembly) build =============================================
# The only supported toolchain, and the version the build record names.
BROWSER_EMSCRIPTEN= 6.0.13
BROWSER_CC= emcc
BROWSER_AR= emar rcu
BROWSER_RANLIB= emranlib
BROWSER_TARGET= wasm32-unknown-emscripten
# Longjmp implementation the archive is compiled with.  Titan's 'titan.h'
# mirrors 'lua_longjmp', so the record carries this mode.
BROWSER_LONGJMP= emscripten
# No -fPIC: the archive is a static, non-PIC artifact.  PIC Wasm objects take
# their addresses from GOT.mem/GOT.func imports (what a side module looks
# like), and every consumer of this archive reads relocatable static objects,
# so a PIC member would be an incompatible artifact.  LUA_USE_POSIX without
# LUA_USE_DLOPEN: a Wasm image has no dynamic loader, and LUA_USE_BROWSER
# drops the executable-relative '!/../' package-path root.  MYCFLAGS is
# appended, exactly as the native CFLAGS does.
BROWSER_SYSCFLAGS= -DLUA_USE_POSIX -DLUA_USE_BROWSER \
	-sSUPPORT_LONGJMP=$(BROWSER_LONGJMP)
# Browser objects live in their own directory, so a native build and a browser
# build of the same tree never reuse or clobber each other's objects.
BROWSER_DIR= browser
BROWSER_OBJDIR= $(BROWSER_DIR)/obj
BROWSER_A= $(BROWSER_DIR)/liblua.a
BROWSER_JS= $(BROWSER_DIR)/lua.js
BROWSER_O= $(addprefix $(BROWSER_OBJDIR)/,$(BASE_O))
BROWSER_JSO= $(BROWSER_OBJDIR)/lua.o
# One homogeneous flag set for every browser object.  The build record states
# a single 'cflags' value for the archive, so per-object extras would make it
# false for the other objects; CMCFLAGS therefore applies to the whole archive
# here instead of only to the compiler modules as the native build does.
BROWSER_CFLAGS= $(CFLAGS) $(CMCFLAGS)
# The objects and the archive record the configuration and the member list
# that produced them, so changing a flag, the toolchain or the object set
# rebuilds them instead of leaving a library that disagrees with its record.
BROWSER_STAMP= $(BROWSER_OBJDIR)/.build-config
# Every header the archived objects compile against: the public ones and the
# internal ones, which are their real prerequisites.  lua.hpp is a C++
# convenience header that the build never includes.  Depending on the whole
# set is deliberate: the per-object dependency list would have to be kept in
# step by hand, and a stale object must never survive a header change.
BROWSER_INC= $(sort $(filter-out lua.hpp,$(wildcard *.h)))
# Command-line overrides for the recursive browser invocations.  MYCFLAGS is
# passed explicitly because this file defines it, which would otherwise hide
# an environment value.
BROWSER_FLAGS= \
	"CC=$(BROWSER_CC)" "AR=$(BROWSER_AR)" "RANLIB=$(BROWSER_RANLIB)" \
	"SYSCFLAGS=$(BROWSER_SYSCFLAGS)" "MYCFLAGS=$(MYCFLAGS)" \
	"MYLDFLAGS=$(MYLDFLAGS)"
NODE= node

# Targets start here.
default: $(PLAT)

all:	$(ALL_T)

o:	$(ALL_O)

a:	$(ALL_A)

ifneq ($(LUA_IMPLIB),)
# GNU Make 4.3+ tracks both outputs of the Windows DLL link.
$(LUA_A) $(LUA_IMPLIB) &: $(BASE_O)
	$(AR) $(LUA_A) $(BASE_O)
	$(RANLIB) $(LUA_A)
else
$(LUA_A): $(BASE_O)
	$(AR) $@ $(BASE_O)
	$(RANLIB) $@
endif

$(LUA_T): $(LUA_O) $(MYLUAOBJS) $(LUA_A) $(LUA_LINK)
	$(CC) -o $@ $(LDFLAGS) $(LUA_O) $(MYLUAOBJS) $(LUA_LINK) $(LIBS)

$(LUAC_T): $(LUAC_O) $(LUA_A) $(LUA_LINK)
	$(CC) -o $@ $(LDFLAGS) $(LUAC_O) $(LUA_LINK) $(LIBS)

# Browser (WebAssembly) build rules.  Static pattern rules, so the objects
# never mix with the native ones in this directory, and the object directory
# is created before the first compile.
$(BROWSER_OBJDIR):
	@mkdir -p $@

# Always re-evaluated, but rewritten only when the configuration or the member
# list changed, so an unchanged build keeps everything up to date.
$(BROWSER_STAMP): browser-config-changed | $(BROWSER_OBJDIR)
	@{ \
		echo "CC=$(CC)"; \
		echo "AR=$(AR)"; \
		echo "RANLIB=$(RANLIB)"; \
		echo "CFLAGS=$(BROWSER_CFLAGS)"; \
		echo "OBJECTS=$(BROWSER_O)"; \
		$(CC) --version 2>/dev/null | head -n 1; \
	} > $@.tmp
	@if cmp -s $@.tmp $@; then $(RM) $@.tmp; else mv $@.tmp $@; fi

$(BROWSER_O) $(BROWSER_JSO): $(BROWSER_OBJDIR)/%.o: %.c $(BROWSER_INC) \
		$(BROWSER_STAMP) | $(BROWSER_OBJDIR)
	$(CC) $(BROWSER_CFLAGS) -c $< -o $@

# Recreated from scratch, so a member that left the object list cannot
# survive in an existing archive.
$(BROWSER_A): $(BROWSER_O) $(BROWSER_STAMP)
	$(RM) $@
	$(AR) $@ $(BROWSER_O)
	$(RANLIB) $@

# A Node image of the interpreter.  It is a toolchain smoke test, not a
# delivery: Titan links the archive, and the runner belongs to the caller.
$(BROWSER_JS): $(BROWSER_JSO) $(BROWSER_A) $(BROWSER_STAMP)
	$(CC) -o $@ $(LDFLAGS) $(BROWSER_JSO) $(BROWSER_A) $(LIBS) \
		-sSUPPORT_LONGJMP=$(BROWSER_LONGJMP)

test:
	./$(LUA_T) -v

clean:
	$(RM) $(ALL_T) $(ALL_O)
	$(RM) -r $(BROWSER_DIR)

depend:
	@$(CC) $(CFLAGS) -MM l*.c

echo:
	@echo "PLAT= $(PLAT)"
	@echo "CC= $(CC)"
	@echo "CFLAGS= $(CFLAGS)"
	@echo "LDFLAGS= $(LDFLAGS)"
	@echo "LIBS= $(LIBS)"
	@echo "AR= $(AR)"
	@echo "RANLIB= $(RANLIB)"
	@echo "RM= $(RM)"
	@echo "UNAME= $(UNAME)"

# Convenience targets for popular platforms.
ALL= all

help:
	@echo "Do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"
	@echo "Do 'make browser' for the WebAssembly archive (Emscripten $(BROWSER_EMSCRIPTEN))."
	@echo "See doc/readme.html for complete instructions."

guess:
	@echo Guessing `$(UNAME)`
	@$(MAKE) `$(UNAME)`

bsd:
	$(MAKE) $(ALL) SYSCFLAGS="$(UNIX_SYSCFLAGS) -DLUA_USE_POSIX -DLUA_USE_DLOPEN" SYSLIBS="-Wl,-E"

FreeBSD NetBSD OpenBSD freebsd:
	$(MAKE) $(ALL) SYSCFLAGS="$(UNIX_SYSCFLAGS) -DLUA_USE_LINUX -DLUA_USE_READLINE -I/usr/include/edit" SYSLIBS="-Wl,-E -ledit" CC="cc"

Linux linux:
	$(MAKE) $(ALL) SYSCFLAGS="$(UNIX_SYSCFLAGS) -DLUA_USE_LINUX" SYSLIBS="-Wl,-E -ldl"

linux-readline:
	$(MAKE) $(ALL) SYSCFLAGS="$(UNIX_SYSCFLAGS) -DLUA_USE_LINUX -DLUA_USE_READLINE" SYSLIBS="-Wl,-E -ldl -lreadline"

Darwin macos macosx:
	$(MAKE) $(ALL) SYSCFLAGS="$(UNIX_SYSCFLAGS) -DLUA_USE_MACOSX" SYSLIBS="-lreadline"

mingw:
	$(MAKE) "LUA_A=lua55.dll" "LUA_T=lua.exe" "LUAC_T=luac.exe" \
	"AR=$(CC) -shared $(MYDLLFLAGS) -Wl,--export-all-symbols $(LUA_IMPLIBFLAGS) -o" \
	"RANLIB=$(if $(MINGW_STRIP),strip --strip-unneeded,:)" \
	"SYSCFLAGS=-DLUA_BUILD_AS_DLL" \
	"SYSLIBS=" "SYSLDFLAGS=$(if $(MINGW_STRIP),-s)" $(ALL)

# Browser (WebAssembly).  'make browser' builds only the static library; the
# interpreter image is a smoke test.  'make browser-config' prints the values
# the install step records, and 'make browser-echo' prints them for the
# recursive invocation's effective CFLAGS.
#
# Always up to date; it exists so the configuration stamp recipe runs on every
# browser build, and rewrites the stamp only when the configuration changed.
browser-config-changed:

browser: browser-version-check
	@$(MAKE) $(BROWSER_A) $(BROWSER_FLAGS)

browser-version-check:
	@version=`$(BROWSER_CC) --version 2>/dev/null | head -n 1 | \
		sed -n 's/.*) \([0-9][0-9.]*\).*/\1/p'`; \
	if [ "$$version" != "$(BROWSER_EMSCRIPTEN)" ]; then \
		echo "Error: 'make browser' requires Emscripten $(BROWSER_EMSCRIPTEN);" \
			"'$(BROWSER_CC)' reports '$${version:-missing}'." >&2; \
		echo "Install it with 'emsdk install $(BROWSER_EMSCRIPTEN) &&" \
			"emsdk activate $(BROWSER_EMSCRIPTEN)' and source emsdk_env.sh." >&2; \
		exit 1; \
	fi

browser-js: browser-version-check
	@$(MAKE) $(BROWSER_JS) $(BROWSER_FLAGS)

browser-test: browser-js
	@$(NODE) $(BROWSER_JS) -v
	@$(NODE) $(BROWSER_JS) -e \
		'assert(1 + 1 == 2); assert(("ok"):upper() == "OK"); assert(package.path:match("^share/lua/"), "browser package.path: " .. package.path); print("browser smoke ok")'

browser-config:
	@$(MAKE) --no-print-directory browser-echo $(BROWSER_FLAGS)

browser-echo:
	@echo "browser_archive= $(BROWSER_A)"
	@echo "browser_src= ."
	@echo "browser_root= .."
	@echo "browser_headers= $(BROWSER_INC)"
	@echo "browser_cc= $(BROWSER_CC)"
	@echo "browser_target= $(BROWSER_TARGET)"
	@echo "browser_emscripten_version= $(BROWSER_EMSCRIPTEN)"
	@echo "browser_sjlj= $(BROWSER_LONGJMP)"
	@echo "browser_cflags= $(BROWSER_CFLAGS)"

# Targets that do not create files (not all makes understand .PHONY).
.PHONY: all $(PLATS) help test clean default o a depend echo \
	browser browser-version-check browser-js browser-test browser-config \
	browser-echo browser-config-changed

# Compiler modules may use special flags.
llex.o:
	$(CC) $(CFLAGS) $(CMCFLAGS) -c llex.c

lparser.o:
	$(CC) $(CFLAGS) $(CMCFLAGS) -c lparser.c

lcode.o:
	$(CC) $(CFLAGS) $(CMCFLAGS) -c lcode.c

# DO NOT DELETE

lapi.o: lapi.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h ldebug.h ldo.h lfunc.h lgc.h lstring.h \
 ltable.h lundump.h lvm.h
lauxlib.o: lauxlib.c lprefix.h lua.h luaconf.h lauxlib.h llimits.h
lbaselib.o: lbaselib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
lcode.o: lcode.c lprefix.h lua.h luaconf.h lcode.h llex.h lobject.h \
 llimits.h lzio.h lmem.h lopcodes.h lparser.h ldebug.h lstate.h ltm.h \
 ldo.h lgc.h lstring.h ltable.h lvm.h lopnames.h
lcorolib.o: lcorolib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
lctype.o: lctype.c lprefix.h lctype.h lua.h luaconf.h llimits.h
ldblib.o: ldblib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h llimits.h
ldebug.o: ldebug.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h lcode.h llex.h lopcodes.h lparser.h \
 ldebug.h ldo.h lfunc.h lstring.h lgc.h ltable.h lvm.h
ldo.o: ldo.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h ldebug.h ldo.h lfunc.h lgc.h lopcodes.h \
 lparser.h lstring.h ltable.h lundump.h lvm.h
ldump.o: ldump.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h lgc.h ltable.h lundump.h
lfunc.o: lfunc.c lprefix.h lua.h luaconf.h ldebug.h lstate.h lobject.h \
 llimits.h ltm.h lzio.h lmem.h ldo.h lfunc.h lgc.h
lgc.o: lgc.c lprefix.h lua.h luaconf.h ldebug.h lstate.h lobject.h \
 llimits.h ltm.h lzio.h lmem.h ldo.h lfunc.h lgc.h lstring.h ltable.h
linit.o: linit.c lprefix.h lua.h luaconf.h lualib.h lauxlib.h llimits.h
liolib.o: liolib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h llimits.h
llex.o: llex.c lprefix.h lua.h luaconf.h lctype.h llimits.h ldebug.h \
 lstate.h lobject.h ltm.h lzio.h lmem.h ldo.h lgc.h llex.h lparser.h \
 lstring.h ltable.h
lmathlib.o: lmathlib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
lmem.o: lmem.c lprefix.h lua.h luaconf.h ldebug.h lstate.h lobject.h \
 llimits.h ltm.h lzio.h lmem.h ldo.h lgc.h
loadlib.o: loadlib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
lobject.o: lobject.c lprefix.h lua.h luaconf.h lctype.h llimits.h \
 ldebug.h lstate.h lobject.h ltm.h lzio.h lmem.h ldo.h lstring.h lgc.h \
 lvm.h
lopcodes.o: lopcodes.c lprefix.h lopcodes.h llimits.h lua.h luaconf.h \
 lobject.h
loslib.o: loslib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h llimits.h
lparser.o: lparser.c lprefix.h lua.h luaconf.h lcode.h llex.h lobject.h \
 llimits.h lzio.h lmem.h lopcodes.h lparser.h ldebug.h lstate.h ltm.h \
 ldo.h lfunc.h lstring.h lgc.h ltable.h
lstate.o: lstate.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h ldebug.h ldo.h lfunc.h lgc.h llex.h \
 lstring.h ltable.h
lstring.o: lstring.c lprefix.h lua.h luaconf.h ldebug.h lstate.h \
 lobject.h llimits.h ltm.h lzio.h lmem.h ldo.h lstring.h lgc.h
lstrlib.o: lstrlib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
ltable.o: ltable.c lprefix.h lua.h luaconf.h ldebug.h lstate.h lobject.h \
 llimits.h ltm.h lzio.h lmem.h ldo.h lgc.h lstring.h ltable.h lvm.h
ltablib.o: ltablib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
ltm.o: ltm.c lprefix.h lua.h luaconf.h ldebug.h lstate.h lobject.h \
 llimits.h ltm.h lzio.h lmem.h ldo.h lgc.h lstring.h ltable.h lvm.h
lua.o: lua.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h llimits.h
luac.o: luac.c lprefix.h lua.h luaconf.h lauxlib.h lapi.h llimits.h \
 lstate.h lobject.h ltm.h lzio.h lmem.h ldebug.h lopcodes.h lopnames.h \
 lundump.h
lundump.o: lundump.c lprefix.h lua.h luaconf.h ldebug.h lstate.h \
 lobject.h llimits.h ltm.h lzio.h lmem.h ldo.h lfunc.h lstring.h lgc.h \
 ltable.h lundump.h
lutf8lib.o: lutf8lib.c lprefix.h lua.h luaconf.h lauxlib.h lualib.h \
 llimits.h
lvm.o: lvm.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h ldebug.h ldo.h lfunc.h lgc.h lopcodes.h \
 lstring.h ltable.h lvm.h ljumptab.h
lzio.o: lzio.c lprefix.h lua.h luaconf.h lapi.h llimits.h lstate.h \
 lobject.h ltm.h lzio.h lmem.h

# (end of Makefile)
