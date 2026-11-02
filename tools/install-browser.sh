#!/bin/sh
#
# Install the browser (WebAssembly) Lua library, the Lua headers the build
# compiled against, and the build record that Titan verifies.
#
# From the top-level directory of the fork:
#
#   make install-browser PREFIX=/some/prefix
#
# which expands to this script, driven by the build configuration that
# 'make -s browser-config' prints on stdin:
#
#   cd src && make -s browser-config |
#       sh ../tools/install-browser.sh /some/prefix/lib/browser
#
# The destination holds:
#
#   liblua.a            the Wasm archive built by 'make browser'
#   include/*.h         every header the archive's objects compiled against
#   liblua-config.txt   the build record (see README.md, "Build record")
#
# This script writes only below the destination: it never touches a native
# installation.  It never runs a host Lua interpreter either, which would be a
# different Lua version from the one installed here; everything in the record
# is compiled, digested or read out of the archive.
#
# A tarball build has no git metadata.  Pass the commit explicitly then:
#
#   FORK_REVISION=<40-hex commit> make install-browser PREFIX=/some/prefix

set -eu

fail() {
	printf 'install-browser: %s\n' "$*" >&2
	exit 1
}

say() {
	printf '%s\n' "$*"
}

# One leading space appears because make prints 'key= value'.
trim() {
	printf '%s' "${1# }"
}

dest=${1:-}
if [ -z "$dest" ]; then
	echo 'usage: install-browser.sh DESTINATION_DIR < build-config' >&2
	echo "(run 'make install-browser PREFIX=/some/prefix' instead)" >&2
	exit 2
fi

script_dir=$(cd "$(dirname "$0")" && pwd)
features_reader=$script_dir/wasm-target-features.awk
[ -f "$features_reader" ] || fail "missing helper: $features_reader"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/lua-browser.XXXXXX") ||
	fail 'cannot create a temporary directory'
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

cat >"$tmp/config"

# The build configuration has a closed key set: an unknown, duplicated or
# missing key means this script and the Makefile disagree, which must never
# pass silently.
archive=
src=
root=
headers=
cc=
target=
emscripten_version=
sjlj=
cflags=
# Duplicate detection tracks the keys themselves, not their values: an empty
# first value must not let a second occurrence through as if it were new.
seen_keys=
take() {
	case " $seen_keys " in
	*" $1 "*) fail "duplicate '$1' in the build configuration" ;;
	esac
	seen_keys="$seen_keys $1"
}
while IFS= read -r line || [ -n "$line" ]; do
	case $line in
	'' | ' '*)
		fail "malformed line in the build configuration: '$line'" ;;
	browser_archive=*)
		take browser_archive
		archive=$(trim "${line#browser_archive=}") ;;
	browser_src=*)
		take browser_src
		src=$(trim "${line#browser_src=}") ;;
	browser_root=*)
		take browser_root
		root=$(trim "${line#browser_root=}") ;;
	browser_headers=*)
		take browser_headers
		headers=$(trim "${line#browser_headers=}") ;;
	browser_cc=*)
		take browser_cc
		cc=$(trim "${line#browser_cc=}") ;;
	browser_target=*)
		take browser_target
		target=$(trim "${line#browser_target=}") ;;
	browser_emscripten_version=*)
		take browser_emscripten_version
		emscripten_version=$(trim "${line#browser_emscripten_version=}") ;;
	browser_sjlj=*)
		take browser_sjlj
		sjlj=$(trim "${line#browser_sjlj=}") ;;
	browser_cflags=*)
		take browser_cflags
		cflags=$(trim "${line#browser_cflags=}") ;;
	*)
		fail "unknown key in the build configuration: '${line%%=*}'" ;;
	esac
done <"$tmp/config"

[ -n "$archive" ] || fail "the build configuration is missing 'browser_archive'"
[ -n "$src" ] || fail "the build configuration is missing 'browser_src'"
[ -n "$root" ] || fail "the build configuration is missing 'browser_root'"
[ -n "$headers" ] || fail "the build configuration is missing 'browser_headers'"
[ -n "$cc" ] || fail "the build configuration is missing 'browser_cc'"
[ -n "$target" ] || fail "the build configuration is missing 'browser_target'"
[ -n "$emscripten_version" ] ||
	fail "the build configuration is missing 'browser_emscripten_version'"
[ -n "$sjlj" ] || fail "the build configuration is missing 'browser_sjlj'"
[ -n "$cflags" ] || fail "the build configuration is missing 'browser_cflags'"

[ -d "$src" ] || fail "no source directory: $src"
src_abs=$(cd "$src" && pwd)
root_abs=$(cd "$src_abs/$root" 2>/dev/null && pwd) || root_abs=
[ -n "$root_abs" ] || fail "no fork root directory: $src_abs/$root"

# ---- toolchain --------------------------------------------------------------

command -v "$cc" >/dev/null 2>&1 || fail \
	"'$cc' is not on PATH, but the browser target requires Emscripten $emscripten_version; install it with 'emsdk install $emscripten_version && emsdk activate $emscripten_version' and source emsdk_env.sh"

banner=$("$cc" --version 2>/dev/null | head -n 1 || true)
found=$(printf '%s\n' "$banner" |
	sed -n 's/.*) \([0-9][0-9.]*\).*/\1/p')
[ -n "$found" ] ||
	fail "cannot read the Emscripten version from '$cc --version' (it printed '$banner')"
[ "$found" = "$emscripten_version" ] || fail \
	"'$cc' reports Emscripten $found, but the browser target requires $emscripten_version; install it with 'emsdk install $emscripten_version && emsdk activate $emscripten_version' and source emsdk_env.sh"

if command -v sha256sum >/dev/null 2>&1; then
	# Reading from stdin keeps the pathname out of the output, so a path
	# containing a backslash cannot turn the recorded digest into garbage:
	# sha256sum escapes such a pathname and prefixes the whole line with '\'.
	sha256_file() { sha256sum < "$1" | cut -c1-64; }
elif command -v shasum >/dev/null 2>&1; then
	sha256_file() { shasum -a 256 < "$1" | cut -c1-64; }
elif command -v openssl >/dev/null 2>&1; then
	sha256_file() { openssl dgst -sha256 < "$1" | sed 's/.*= *//' | cut -c1-64; }
else
	fail 'no SHA-256 tool found (tried sha256sum, shasum -a 256 and openssl dgst -sha256)'
fi

# ---- the archive ------------------------------------------------------------

archive_path=$src_abs/$archive
[ -f "$archive_path" ] || fail \
	"the browser library is missing: $archive_path; build it with 'make browser' in ${root_abs:-$src_abs}"
[ "$(head -c 8 "$archive_path")" = '!<arch>' ] || fail \
	"$archive_path is not an ar archive; run 'make clean && make browser'"

# ---- the fork revision ------------------------------------------------------

revision=${FORK_REVISION:-}
if [ -z "$revision" ]; then
	# git searches enclosing directories, so a source tree unpacked inside an
	# unrelated checkout would report that repository's commit.  Only a root
	# with its own metadata is this fork's checkout.
	if [ ! -e "$root_abs/.git" ]; then
		fail "cannot determine the fork revision: $root_abs has no .git, and a tarball build has no revision of its own; pass FORK_REVISION=<40-hex commit>"
	fi
	revision=$(git -C "$root_abs" rev-parse HEAD 2>/dev/null || true)
	[ -n "$revision" ] || fail \
		"cannot determine the fork revision: 'git rev-parse HEAD' failed in $root_abs; pass FORK_REVISION=<40-hex commit>"
fi
case $revision in
*[!0-9a-f]*)
	fail "FORK_REVISION must be 40 lowercase hexadecimal characters, got '$revision'" ;;
esac
[ ${#revision} -eq 40 ] ||
	fail "FORK_REVISION must be 40 lowercase hexadecimal characters, got '$revision'"

# ---- the compile flags, defines and numeric configuration -------------------

# The effective values, as the compiler and emcc actually resolve these flags:
# for both, a later occurrence replaces an earlier one.  emcc accepts
# '-sNAME=VALUE' and '-s NAME=VALUE', and both change code generation, so both
# spellings are read here.
cflags_normalized=
defines=
longjmp=
pic_flags=
previous=
for flag in $cflags; do
	cflags_normalized=${cflags_normalized:+$cflags_normalized }$flag
	case $flag in
	-D*) defines=${defines:+$defines }$flag ;;
	-sSUPPORT_LONGJMP=*) longjmp=${flag#-sSUPPORT_LONGJMP=} ;;
	SUPPORT_LONGJMP=*)
		if [ "$previous" = "-s" ]; then
			longjmp=${flag#SUPPORT_LONGJMP=}
		fi ;;
	-fPIC | -fpic | -fPIE | -fpie) pic_flags="$pic_flags $flag" ;;
	esac
	previous=$flag
done
if [ -n "$defines" ]; then
	lua_defines=$(printf '%s\n' $defines | LC_ALL=C sort -u | paste -sd ' ' -)
else
	lua_defines=
fi
# The record states one longjmp mode for the archive, so the effective one --
# the last -s flag emcc sees -- must be that mode.  A caller-owned MYCFLAGS that
# appends another mode would otherwise be certified as this one.
[ -n "$longjmp" ] || fail \
	"the browser build must compile with -sSUPPORT_LONGJMP=$sjlj; the compile flags are: $cflags_normalized"
[ "$longjmp" = "$sjlj" ] || fail \
	"the browser build resolves -sSUPPORT_LONGJMP=$longjmp, but the build record would state sjlj=$sjlj; the compile flags are: $cflags_normalized"
[ -z "$pic_flags" ] || fail \
	"the browser build must not compile position-independent objects ($pic_flags): a PIC Wasm object imports GOT.mem/GOT.func, which a static object reader rejects; the compile flags are: $cflags_normalized"

# The effective Lua platform configuration, as the preprocessor resolves it
# after every caller flag.  Searching the -D tokens alone is not enough: a
# later -U, an assignment such as -DLUA_USE_DLOPEN=1, or an indirect
# enablement such as -DLUA_USE_LINUX leaves those tokens in place.
cat >"$tmp/macros.c" <<'EOF'
#include "luaconf.h"
EOF
macros=$("$cc" -dM -E -I"$src_abs" $cflags "$tmp/macros.c" 2>"$tmp/macros.log") ||
	{
		cat "$tmp/macros.log" >&2
		fail "cannot preprocess luaconf.h with '$cc'"
	}
has_define() {
	printf '%s\n' "$macros" |
		awk -v name="$1" \
			'$1 == "#define" && $2 == name { found = 1 } END { exit !found }'
}
has_define LUA_USE_POSIX || fail \
	"the effective Lua configuration must define LUA_USE_POSIX; the compile flags are: $cflags_normalized"
has_define LUA_USE_BROWSER || fail \
	"the effective Lua configuration must define LUA_USE_BROWSER, which selects browser package paths; a later -U or an indirect -DLUA_USE_LINUX/-DLUA_USE_MACOSX changes it. The compile flags are: $cflags_normalized"
if has_define LUA_USE_DLOPEN; then
	fail "the effective Lua configuration must not define LUA_USE_DLOPEN: a Wasm image has no dynamic loader; the compile flags are: $cflags_normalized"
fi

cat >"$tmp/numeric.c" <<'EOF'
#include "luaconf.h"
lua_probe_integer LUA_INTEGER
lua_probe_number LUA_NUMBER
EOF
# The probe sees the archive's own compile flags; -I points it at this src
# directory, which is where the build finds luaconf.h.
numeric_output=$("$cc" -E -P -I"$src_abs" $cflags "$tmp/numeric.c" 2>"$tmp/numeric.log") ||
	{
		cat "$tmp/numeric.log" >&2
		fail "cannot preprocess luaconf.h with '$cc'"
	}
integer_type=$(printf '%s\n' "$numeric_output" | awk '
	$1 == "lua_probe_integer" {
		sub(/^[ \t]*lua_probe_integer[ \t]+/, "")
		gsub(/[ \t][ \t]*/, " ")
		print
	}')
number_type=$(printf '%s\n' "$numeric_output" | awk '
	$1 == "lua_probe_number" {
		sub(/^[ \t]*lua_probe_number[ \t]+/, "")
		gsub(/[ \t][ \t]*/, " ")
		print
	}')
[ -n "$integer_type" ] || fail 'cannot determine LUA_INTEGER from luaconf.h'
[ -n "$number_type" ] || fail 'cannot determine LUA_NUMBER from luaconf.h'
numeric="integer=$integer_type,float=$number_type"

# ---- the Wasm target features ----------------------------------------------
# A probe object compiled with exactly the recorded flags declares the feature
# set every reader of these objects expects.  Lua's own 'ldo.c' calls setjmp,
# so its object additionally declares '-shared-mem'; that is a per-object
# property of Lua's source, not of the toolchain configuration the record
# describes.

cat >"$tmp/feature-probe.c" <<'EOF'
/* Compiled only to read the toolchain's target_features section. */
int lua_browser_feature_probe(void) { return 0; }
EOF
if ! "$cc" $cflags -c "$tmp/feature-probe.c" -o "$tmp/feature-probe.o" \
		2>"$tmp/feature-probe.log"; then
	cat "$tmp/feature-probe.log" >&2
	fail "cannot compile the Wasm feature probe with the recorded flags: $cflags_normalized"
fi
if ! od -An -v -tu1 "$tmp/feature-probe.o" |
		LC_ALL=C awk -f "$features_reader" >"$tmp/features.txt"; then
	fail "cannot read the 'target_features' section of the toolchain probe object"
fi
wasm_features=$(LC_ALL=C sort "$tmp/features.txt" | paste -sd ' ' -)
[ -n "$wasm_features" ] ||
	fail 'the toolchain probe object declares no Wasm target features'

# ---- install ----------------------------------------------------------------

include_dir=$dest/include
mkdir -p "$include_dir" || fail "cannot create $include_dir"
# The directory must hold exactly the headers of this build, so a header
# renamed or dropped upstream cannot leave a stale file behind that changes
# the digest below.
rm -f "$include_dir"/*.h
installed_headers=
for header in $headers; do
	[ -f "$src_abs/$header" ] || fail "missing header: $src_abs/$header"
	cp "$src_abs/$header" "$include_dir/$header" ||
		fail "cannot install $header"
	chmod 644 "$include_dir/$header"
	installed_headers="$installed_headers $header"
done

cp "$archive_path" "$dest/liblua.a" || fail "cannot install $archive"
chmod 644 "$dest/liblua.a"

# ---- digests, over the installed files themselves ---------------------------

archive_sha256=$(sha256_file "$dest/liblua.a")

# One '<name> <sha256>' line per header, ascending byte order of the line.
: >"$tmp/headers.txt"
for header in $installed_headers; do
	printf '%s %s\n' "$header" "$(sha256_file "$include_dir/$header")" \
		>>"$tmp/headers.txt"
done
LC_ALL=C sort "$tmp/headers.txt" >"$tmp/headers.sorted"
headers_sha256=$(sha256_file "$tmp/headers.sorted")

# ---- the record -------------------------------------------------------------

{
	printf '%s\n' '# Lua 5.5.1 browser build record v1'
	printf 'fork_revision=%s\n' "$revision"
	printf 'archive_sha256=%s\n' "$archive_sha256"
	printf 'headers_sha256=%s\n' "$headers_sha256"
	printf 'emscripten_version=%s\n' "$emscripten_version"
	printf 'target=%s\n' "$target"
	printf 'wasm_features=%s\n' "$wasm_features"
	printf 'sjlj=%s\n' "$sjlj"
	printf 'lua_defines=%s\n' "$lua_defines"
	printf 'numeric=%s\n' "$numeric"
	printf 'cflags=%s\n' "$cflags_normalized"
} >"$dest/liblua-config.txt"
chmod 644 "$dest/liblua-config.txt"

header_count=$(printf '%s\n' $installed_headers | wc -l | tr -d ' ')
say "installed $dest/liblua.a (sha256 $archive_sha256)"
say "installed $header_count headers in $include_dir (digest $headers_sha256)"
say "wrote $dest/liblua-config.txt (fork revision $revision, Emscripten $emscripten_version)"
