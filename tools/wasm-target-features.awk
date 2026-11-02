# Print the entries of a Wasm object's 'target_features' custom section, one
# per line, each as '<prefix><name>' where <prefix> is '+', '-' or '='.
#
# Input is the object's raw bytes as decimal values, as produced by
# 'od -An -v -tu1 OBJECT'.  The reader is deliberately tiny and total: it
# bounds every read by the object size and fails instead of guessing.
#
# Why the section and not a toolchain convenience list: emcc 6.0.13 has no
# option that prints the target features it will emit, and
# 'wasm-opt --print-features' reports binaryen's own canonicalization
# ('--enable-*' names, a different set), while Titan's relocatable-Wasm reader
# parses exactly this section.  Reading the section keeps the build record and
# the objects in agreement by construction.

function die(message) {
	print "target_features: " message > "/dev/stderr"
	exit 1
}

# Unsigned LEB128.  Returns the decoded value and leaves 'pos' just past it.
function leb128(   value, shift, digit) {
	value = 0
	shift = 1
	while (1) {
		if (pos > count) die("truncated LEB128")
		digit = byte_at[pos++]
		value = value + (digit % 128) * shift
		if (digit < 128)
			return value
		shift = shift * 128
		if (shift > 268435456) die("LEB128 overflow")
	}
}

# A length-prefixed byte string, used for section and feature names.
function name_of(   name_length, text, i) {
	name_length = leb128()
	if (pos + name_length - 1 > count)
		die("name runs past the object")
	text = ""
	for (i = 0; i < name_length; i++)
		text = text sprintf("%c", byte_at[pos++])
	return text
}

{
	for (field = 1; field <= NF; field++)
		byte_at[++count] = $field + 0
}

END {
	if (count < 8)
		die("object is too small to be WebAssembly")
	if (byte_at[1] != 0 || byte_at[2] != 97 || byte_at[3] != 115 \
			|| byte_at[4] != 109)
		die("not a Wasm object")
	pos = 9
	found = 0
	while (pos <= count) {
		id = byte_at[pos++]
		size = leb128()
		end = pos + size - 1
		if (end > count)
			die("section overruns the object")
		if (id == 0 && name_of() == "target_features") {
			if (found)
				die("duplicate 'target_features' section")
			found = 1
			entries = leb128()
			for (i = 0; i < entries; i++) {
				if (pos > count)
					die("truncated feature entry")
				prefix = byte_at[pos++]
				feature = name_of()
				if (prefix == 43)
					sign = "+"
				else if (prefix == 45)
					sign = "-"
				else if (prefix == 61)
					sign = "="
				else
					die("unknown feature prefix in 'target_features'")
				print sign feature
			}
		}
		pos = end + 1
	}
	if (!found)
		die("the object has no 'target_features' section")
}
