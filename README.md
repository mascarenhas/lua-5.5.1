# Lua 5.5.1 for Titan

This is Lua 5.5.1, released on 24 Jul 2026, intended to compile Lua with default search paths that make it work better with Titan.

Additionaly, for Windows mingw builds (the only ones currently tested with Titan 0.6), compiles `lua55.dll` and its import library from stock sources with `-DLUA_BUILD_AS_DLL`, linked with `-Wl,--export-all-symbols`, so the internal Lua functions and data that Titan uses are also exported.

In Linux and MacOS Titan by default expects static Lua builds, so it can get to these functions by just linking with the regular Lua archive file.

The Unix targets (`linux`, `linux-readline`, `macosx`, `bsd`, and `freebsd`) compile with `-fPIC` by default, so `liblua.a` is position-independent and Titan can link it into shared objects: its `titan.so` support module and every compiled Titan module. Stock Lua leaves that flag to the caller. Here it is part of the targets' `SYSCFLAGS`, so setting `MYCFLAGS` for other options does not drop it. The `mingw` target is unchanged.

## Installation

Build for the supported platforms with the usual targets:

```bash
$ make linux-readline
```

```bash
$ make linux
```

```bash
$ make macosx
```

```cmd
> make mingw
```

Then pass a `PREFIX` to `make install` to install the Lua files to that prefix:

For Linux/MacOS:

```bash
$ PREFIX=$HOME/.local make install
```

For Windows:

```cmd
> set PREFIX=%USERPROFILE%\.local && make install
```

Even in Linux/MacOS you can compile once and install in different paths, as Lua will derive its search paths from where it is running, similar to what the stock Lua build does in Windows. There, as on Windows, `!` in a search path means the directory of the running executable, and the defaults are rooted at `!/../` (for example `!/../lib/lua/5.5/?.so`).
