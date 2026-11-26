#!/usr/bin/env bash
# Offline x86 test of a port before it goes anywhere near a device:
#   tools/test-port.sh 4k-eq
# Links the module + the mpc-vst-plugins wrapper + this repo's adapter with tools/host_test.c under
# ASan/UBSan and runs it: two instances, every parameter's name/round trip, option lists, note -> audio,
# state chunk save/restore. Exit status is the test's. Needs Docker.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
id="${1:?usage: tools/test-port.sh <port id>}"
PD="$REPO/ports/$id"
MV="${MV:-$REPO/.build/mpc-vst-plugins}"
[ -d "$MV/tools" ] || { echo "run ./build.sh $id once first (it fetches mpc-vst-plugins)" >&2; exit 1; }
"$REPO/tools/fetch-upstream.sh" "$id" >/dev/null
PICKED_ADAPTER="$(python3 "$REPO/tools/port_vars.py" "$PD" | sed -n "s/^ADAPTER='\(.*\)'$/\1/p")"
eval "$(python3 "$MV/tools/gen_vst.py" "$PD/vst.json" --shell)"
ADAPTER="$PICKED_ADAPTER"
ADAPTER_SRC="$REPO/adapters/$ADAPTER/${ADAPTER}_engine.c"
python3 "$MV/tools/gen_vst.py" "$PD/vst.json" --params-h >/dev/null
export SOURCES CFLAGS LIBS
docker run --rm -u "$(id -u):$(id -g)" -v "$REPO":/w -v "$MV":/mv:ro -v "$ADAPTER_SRC":/src/adapter.c:ro \
    -e SOURCES -e CFLAGS -e LIBS -w /w gcc:12 bash -euc '
    SAN="${SAN:--fsanitize=address,undefined -fno-omit-frame-pointer -g -O2}"
    OUT="ports/'"$id"'/build"; mkdir -p "$OUT/host"
    OBJS=""
    for f in $SOURCES; do
        o="$OUT/host/${f//\//_}.o"
        case "$f" in
            *.cpp|*.cc|*.cxx) g++ $SAN -std=gnu++17 $CFLAGS -I"$OUT" -I/mv/wrapper -c "$f" -o "$o" ;;
            *) gcc $SAN -std=gnu11 $CFLAGS -I"$OUT" -I/mv/wrapper -c "$f" -o "$o" ;;
        esac
        OBJS="$OBJS $o"
    done
    for f in /mv/tools/host_test.c /mv/wrapper/vst2_wrap.c /src/adapter.c; do
        o="$OUT/host/$(basename "$f").o"
        gcc $SAN -std=gnu11 -I"$OUT" -I/mv/wrapper -c "$f" -o "$o"
        OBJS="$OBJS $o"
    done
    g++ $SAN $OBJS $LIBS -lpthread -ldl -o "$OUT/host/test"
    ASAN_OPTIONS=detect_leaks=0 "$OUT/host/test"
'
