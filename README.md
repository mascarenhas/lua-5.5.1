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

## Browser (WebAssembly)

`make browser` builds a static Lua library for WebAssembly with wasi-sdk 34.0,
and `make install-browser` installs it together with a build record that
describes exactly how it was built. Native targets are untouched: browser
objects live in `src/browser/obj`, and the browser installation is confined to
`PREFIX/lib/browser`.

The archive is compiled with

| Setting | Value |
| --- | --- |
| compiler | wasi-sdk 34.0's `clang` (the only accepted release, named by the first line of the sdk's `VERSION` file beside its `bin/`), `--target=wasm32-wasip1` |
| archiver | `llvm-ar rc`, ranlib `llvm-ranlib` |
| objects | `src/browser/obj/*.o`, separate from the native build |
| `-fPIC` | absent: the archive is a static, non-PIC artifact. A PIC Wasm object carries `GOT.mem`/`GOT.func` imports — the shape of a side module — which the consumers of a static Lua archive reject |
| defines | `-DLUA_USE_BROWSER -DLUA_USE_OFF_T -Dl_signalT=int -DLUAI_MAXCCALLS=100 -D_WASI_EMULATED_PROCESS_CLOCKS` |
| platform | no `LUA_USE_POSIX`: wasi-libc has no signals, processes, `popen` or `mkstemp`. `LUA_USE_OFF_T` keeps `fseeko`/`ftello`, `l_signalT=int` keeps `<signal.h>` out of `lstate.h`, and the process-clock emulation supplies `clock()` |
| dynamic loading | none: no `LUA_USE_DLOPEN`, no readline |
| longjmp | `-mexception-handling -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false`, in `SYSCFLAGS` and therefore on every compile line |
| debug info | `-gdwarf-4 -gline-tables-only`, the line tables Titan maps into its trace table |
| package paths | `LUA_USE_BROWSER` drops the executable-relative `!/../` root, leaving `share/lua/5.5/…`, `lib/lua/5.5/…` and `./…` |

`MYCFLAGS` is appended to `CFLAGS`, exactly as in the native build. `CMCFLAGS`
applies to every browser object here, not only to the compiler modules as the
native build does: the record states one `cflags` value for the whole archive,
so a per-object extra would make that statement false for the other objects.
Use the recorded `MYCFLAGS` and `CMCFLAGS` inputs for supported extras.

Longjmp uses Wasm exception handling with the **standard** (exnref)
instruction encoding; LLVM still selects the legacy encoding unless
`-wasm-use-legacy-eh=false` says otherwise. Every consumer must compile with
the same settings and link wasi-sdk's `-lsetjmp`; changing only a final link
flag cannot change the longjmp lowering of an old object. This choice is
independent of coroutine stack switching. The browser-only
`LUAI_MAXCCALLS=100` limit remains unchanged; native targets retain 200.

Without `LUA_USE_POSIX`, the browser build also guards the few library
functions wasi-libc lacks: `os.date` and `os.time` use `gmtime_r` and
`localtime_r`, `os.tmpname` fails ("unable to generate a unique filename"),
`io.tmpfile` fails with `ENOSYS`, and `os.execute` reports no shell.

The browser objects depend on every header they compile against, and they
record the configuration and the member list that produced them
(`src/browser/obj/.build-config`). Changing a header, `CC`, `CFLAGS`,
`CMCFLAGS`, the object list or the wasi-sdk therefore rebuilds them, and
`liblua.a` is recreated from exactly the current member list, so a removed
object cannot survive as a stale member.

```bash
$ make browser BROWSER_CC=/path/to/wasi-sdk-34.0/bin/clang
$ make install-browser PREFIX=$HOME/.local BROWSER_CC=/path/to/wasi-sdk-34.0/bin/clang
```

With the sdk's `bin/` first on `PATH`, the default `BROWSER_CC=clang` (with
`llvm-ar` and `llvm-ranlib`) selects it. `make browser` refuses to run when the
compiler is missing or does not belong to wasi-sdk 34.0, and names the release
to install. `make browser-test` additionally links `src/browser/lua.wasm`, a
WASI command image of the interpreter, and runs it under Node's `node:wasi`
through `tools/browser-lua.mjs` as a smoke test; that image is a toolchain
check, not a delivery. It uses `node` from `PATH`; pass `NODE=/path/to/node`
to choose another one. A build needs a Linux or macOS host; the `make browser`
recipe itself needs a POSIX shell.

## The browser installation

`make install-browser PREFIX=<prefix>` writes only below
`<prefix>/lib/browser` and never runs a host Lua interpreter: the archive is
WebAssembly, so everything the record states is compiled, digested or read out
of the archive instead.

```text
<prefix>/lib/browser/liblua.a            the Wasm archive
<prefix>/lib/browser/include/*.h         every header the archive compiled against
<prefix>/lib/browser/liblua-config.txt   the build record
```

The include directory holds every `src/*.h` the archive's objects include, which
is all of them except `lua.hpp`, a C++ convenience header. That is intentional:
consumers compile against Lua internals, so `lstate.h`, `lobject.h`, `lapi.h`,
`lfunc.h`, `lgc.h`, `ldo.h`, `ltm.h`, `lzio.h`, `llimits.h`, `lprefix.h`,
`lundump.h`, `lvm.h`, `lcode.h`, `lparser.h`, `llex.h`, `lopcodes.h`,
`lopnames.h`, `ljumptab.h`, `lctype.h`, `lstring.h`, `ltable.h`, `ldebug.h`,
`lmem.h` and `luaconf.h` are installed next to the public `lua.h`, `lualib.h`
and `lauxlib.h`.

`include/` is emptied of `*.h` before the install, so a header that disappears
upstream cannot leave a stale file behind that changes `headers_sha256`.

## The build record

`liblua-config.txt` is UTF-8 text: one banner line, then one `key=value` line
per key, in this order. The key set is closed: a reader must reject an unknown,
duplicated or missing key.

```text
# Lua 5.5.1 browser build record v2
fork_revision=<40-hex commit>
archive_sha256=<SHA-256 of lib/browser/liblua.a>
headers_sha256=<digest over the sorted (name, SHA-256) of include/*.h>
wasi_sdk_version=34.0
target=wasm32-wasip1
wasm_features=<canonical sorted feature list>
sjlj=wasm-exnref
lua_defines=<sorted -D flags>
numeric=<luaconf numeric configuration>
cflags=<effective compile flags>
```

| Key | Meaning |
| --- | --- |
| `fork_revision` | The commit the library was built from, `git rev-parse HEAD` of this repository, read only when the source root has its own `.git`: a tree unpacked inside an unrelated checkout must not inherit that repository's commit. A tarball build has no git metadata, so it must pass `FORK_REVISION=<40-hex commit>`; without it the install fails and says so. |
| `archive_sha256` | SHA-256 of the installed `liblua.a`, lowercase hex. `llvm-ar` writes deterministic archives, so the value is stable for a given commit, flags and wasi-sdk release. |
| `headers_sha256` | Digest over the installed headers; byte format below. |
| `wasi_sdk_version` | The pin, checked against the first line of the recording compiler's `../VERSION` during the install. |
| `target` | The physical ABI/toolchain triple, which must also be the effective `--target` of `cflags`. |
| `wasm_features` | The `target_features` entries of an object compiled with these flags: space-separated `+name`/`-name` tokens, ascending byte order of the token. |
| `sjlj` | The longjmp mode the archive was compiled with, `wasm-exnref`: Wasm exception handling (`-mexception-handling`) with LLVM's Wasm longjmp lowering (`-mllvm -wasm-enable-sjlj`) and the standard encoding (`-mllvm -wasm-use-legacy-eh=false`). These two are the only backend options `cflags` may pass, each once and in the separate `-mllvm OPTION` spelling, which is what Titan's compiler accepts in a record. |
| `lua_defines` | The `-D` flags of `cflags`, sorted with `LC_ALL=C sort -u`, space-separated. |
| `numeric` | `integer=<C type of LUA_INTEGER>,float=<C type of LUA_NUMBER>`, as the preprocessor expands them from the installed `luaconf.h`. |
| `cflags` | The effective compile flags for every object in the archive, whitespace-normalized to single spaces, in compiler order, including `MYCFLAGS` and `CMCFLAGS`. |

### Byte format of `headers_sha256`

For every installed header, in ascending byte order of the whole line, which
for these names is the same as the order of the file names, emit the line

```text
<name> <sha256-of-that-file-in-lowercase-hex>\n
```

that is: the file name, one space, 64 lowercase hexadecimal digits, one LF
(`0x0A`), no CR, no trailing spaces. Concatenate those lines; `headers_sha256`
is the SHA-256 of that byte string, in lowercase hex. The header files are only
ever addressed by base name; there are no subdirectories.

To recompute it from an installation, in a POSIX shell:

```bash
$ cd <prefix>/lib/browser/include &&
  for h in *.h; do printf '%s %s\n' "$h" "$(sha256sum "$h" | cut -c1-64)"; done |
  LC_ALL=C sort | sha256sum
```

The comparable Python is `hashlib.sha256("".join("%s %s\n" % (name,
sha256_file(join(dir, name))) for name in sorted(names)).encode()).hexdigest()`,
where `sorted` is Python's byte-order sort of the names.

### `wasm_features`

This is the list of features declared by an object the build compiles with the
recorded flags, read from its `target_features` custom section.
`wasm-opt --print-features` reports binaryen's own canonicalization
(`--enable-*` names, a different set), so `tools/wasm-target-features.awk` reads
the section from a one-function probe object compiled during the install.

The baseline includes `+exception-handling`. Per-object feature restrictions
remain in each object's `target_features`; the record describes the common
toolchain configuration which a consumer's objects must match.

### Failure modes

`install-browser` stops with a message naming the fix when

- the compiler is not on `PATH`, or its `../VERSION` is missing or names a
  release other than 34.0;
- the archive is missing (`make browser`), or is not an `ar` archive;
- the source root has no `.git` (a tarball) and `FORK_REVISION` was not given,
  or `FORK_REVISION` is not 40 lowercase hex characters;
- the effective Lua configuration, read from the preprocessor after every
  caller flag, defines `LUA_USE_POSIX` or `LUA_USE_DLOPEN` (directly, through
  an assignment or through an indirect `LUA_USE_LINUX`), or does not define
  `LUA_USE_BROWSER`;
- the effective `--target` differs from the recorded `target`, or the flags
  use the separate `-target TRIPLE` spelling;
- the recorded `sjlj` is not `wasm-exnref`; the flags lack
  `-mexception-handling`, or their `-mllvm` options are not exactly
  `-wasm-enable-sjlj` and `-wasm-use-legacy-eh=false`; or the flags use the
  joined `-mllvm=OPTION` spelling or another exception switch
  (`-mno-exception-handling`, `-m[no-]legacy-exception-handling`,
  `-f[no-]wasm-exceptions`);
- the flags request position-independent objects (`-fPIC`, `-fpic`, `-fPIE`,
  `-fpie`);
- `luaconf.h` cannot be preprocessed, or does not define `LUA_INTEGER` or
  `LUA_NUMBER`;
- the feature probe cannot be compiled, or declares no features;
- no SHA-256 tool (`sha256sum`, `shasum -a 256`, `openssl dgst -sha256`) can be
  found.

