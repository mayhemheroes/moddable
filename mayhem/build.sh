#!/usr/bin/env bash
#
# mayhem/build.sh — build the xst OSS-Fuzz/libFuzzer harness (+ standalone reproducer).
# Match OSS-Fuzz projects/xs/build.sh: let xst.mk link the fuzz binary (custom relinks broke
# sanitizer coverage → 0 Mayhem edges). Only build a separate standalone reproducer here.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# OSS-Fuzz sets -fsanitize=fuzzer-no-link in CFLAGS/CXXFLAGS; without it the .o files get no
# edge counters and Mayhem reports 0 edges even though the link step pulls in libFuzzer.
FUZZ_SANITIZER_FLAGS="-fsanitize=address,fuzzer-no-link -fno-sanitize-recover=all -fno-omit-frame-pointer"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS

export MODDABLE="$SRC"
export BUILD_DIR="$SRC/build"

export CFLAGS="${CFLAGS:-} $FUZZ_SANITIZER_FLAGS $DEBUG_FLAGS"
export CXXFLAGS="${CXXFLAGS:-} $FUZZ_SANITIZER_FLAGS $DEBUG_FLAGS"

OUT="/mayhem"
mkdir -p "$OUT"
SEED_DIR="$SRC/mayhem/xst/testsuite"
[ -n "$(ls -A "$SEED_DIR"/*.js 2>/dev/null)" ] || { echo "ERROR: missing seed corpus under $SEED_DIR" >&2; exit 1; }

cd "$SRC/xs/makefiles/lin"
# OSS-Fuzz: FUZZING=1 OSSFUZZ=1 FUZZ_METER=2560000 make debug
make -j"$MAYHEM_JOBS" FUZZING=1 OSSFUZZ=1 FUZZ_METER=2560000 debug

BIN_DIR="$BUILD_DIR/bin/lin/debug"
TMP_DIR="$BUILD_DIR/tmp/lin/debug/xst"
XST_MK="$SRC/xs/makefiles/lin/xst.mk"
[ -x "$BIN_DIR/xst" ] || { echo "ERROR: $BIN_DIR/xst not built" >&2; exit 1; }

cp "$BIN_DIR/xst" "$OUT/xst"
cp "$SRC/mayhem/xst.options" "$OUT/xst.options"

# Standalone reproducer: same OBJECTS order as xst.mk + baked ASan defaults + run-once driver.
STANDALONE_O="$TMP_DIR/standalone_main.o"
ASAN_OPTS_O="$TMP_DIR/asan_default_options.o"
mapfile -t OBJECTS < <(python3 - "$XST_MK" "$TMP_DIR" <<'PY'
import sys
mk, tmp = sys.argv[1], sys.argv[2]
objs, in_objs = [], False
for line in open(mk):
    if line.startswith("OBJECTS = "):
        in_objs = True
        continue
    if not in_objs:
        continue
    if line and not line[0].isspace():
        break
    entry = line.strip().rstrip("\\").strip()
    if entry:
        objs.append(entry.replace("$(TMP_DIR)", tmp))
for o in objs:
    print(o)
PY
)
[ "${#OBJECTS[@]}" -gt 0 ] || { echo "build.sh: failed to parse OBJECTS from $XST_MK" >&2; exit 1; }

LIBS="-ldl -lm -lpthread -latomic -lrt"
$CC $FUZZ_SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/asan_default_options.c" -o "$ASAN_OPTS_O"
$CC $FUZZ_SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$STANDALONE_O"
$CXX -rdynamic $FUZZ_SANITIZER_FLAGS $DEBUG_FLAGS \
    "${OBJECTS[@]}" "$ASAN_OPTS_O" "$STANDALONE_O" \
    $LIBS \
    -o "$OUT/xst-standalone"

echo "build.sh complete:"
ls -la "$OUT/xst" "$OUT/xst-standalone"
ls "$SEED_DIR" | wc -l | xargs echo "seed corpus files:"
