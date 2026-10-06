# Lua 5.5.1 for Titan

This is Lua 5.5.1, released on 24 Jul 2026, intended to compile Lua with default search paths that make it work better with Titan.

Additionaly, for Windows mingw builds (the only ones currently tested with Titan 0.6), compiles `lua55.dll` and its import library in a way that the internal Lua functions that Titan uses are exported.

In Linux and MacOS Titan by default expects static Lua builds, so it can get to these functions by just linking with the regular Lua archive file.

## Installation

Either `export TITAN_LIBRARY_VERSION=0.6` or pass `TITAN_LIBRARY_VERSION=0.6` to the make command when building across the supported platforms:

```bash
$ TITAN_LIBRARY_VERSION=0.6 make linux-readline
```

```bash
$ TITAN_LIBRARY_VERSION=0.6 make linux
```

```bash
$ TITAN_LIBRARY_VERSION=0.6 make macosx
```

```cmd
> set TITAN_LIBRARY_VERSION=0.6 && make mingw
```

Then pass a `PREFIX` and the `TITAN_LIBRARY_VERSION` (if not exported) to `make install` to install the Lua files to that prefix:

For Linux/MacOS:

```bash
$ PREFIX=$HOME/.local TITAN_LIBRARY_VERSION=0.6 make install
```

For Windows:

```cmd
> set PREFIX=%USERPROFILE%\.local && set TITAN_LIBRARY_VERSION=0.6 && make install
```

Even in Linux/MacOS you can compile once and install in different paths, as Lua will derive its search paths from where it is running, similar to what the stock Lua build does in Windows.
