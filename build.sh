#!/usr/bin/env bash
# Build and package the Schwung module ports as MPC/Force plugin releases.
#
#   ./build.sh                  build and package every port in ports/
#   ./build.sh 4k-eq midiverb   only these ports
#   TARGET=aarch64 ./build.sh   Gen2 (aarch64) build, for a port whose vst.json lists it in "targets"
#   only=1 ./build.sh 4k-eq     stop after the .so and the skin (no zip)
#
# Per port:
#   1. fetch the pinned upstream module source (.build/upstream/, tools/fetch-upstream.sh)
#   2. render the stock Q-Link skin, params.h and the plugin-list entry from ports/<id>/vst.json
#      with tools/gen_vst.py from mpc-vst-plugins at MV_REF (python:3.11-slim + Pillow, the image
#      the upstream tools use, so the skin comes out byte-identical)
#   3. compile the module UNCHANGED, linked with the mpc-vst-plugins wrapper and this repo's Schwung
#      adapter (adapters/<adapter>/), in arm32v7/gcc:11-bullseye for Gen1 (GLIBC <= 2.29)
#   4. package with tools/release.py, which writes the current install.sh / uninstall.sh /
#      plugin_list.awk templates, plugin.json (MPC OS 3.10.1+) and mpc-plugin.json: dist/*.zip
#
# Needs Docker and python3. Upload dist/*.zip as a GitHub release: that zip is what the catalog lists.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
MV="${MV:-$REPO/.build/mpc-vst-plugins}"
MV_REF="${MV_REF:-c4f8b7d613584f2bc6d1c10872e31a8508562b26}"   # wrapper + tools/gen_vst.py + tools/release.py
TARGET="${TARGET:-armv7}"
DIST="${DIST:-$REPO/dist}"
RELEASE_REPO="${RELEASE_REPO:-michaelmenesescs/mpc-schwung-ports}"
U="$(id -u):$(id -g)"
PYIMAGE=python:3.11-slim
ARTIMG=gcc:12
case "$TARGET" in
    armv7)   IMG=arm32v7/gcc:11-bullseye ; PLAT=linux/arm/v7 ;;
    aarch64) IMG=arm64v8/gcc:12-bookworm ; PLAT=linux/arm64 ;;
    *) echo "TARGET must be armv7 or aarch64" >&2; exit 1 ;;
esac

mkdir -p "$DIST"

if [ ! -d "$MV/.git" ]; then
    echo "== fetching mpc-vst-plugins @ $MV_REF"
    mv="${MV%/*}"; mkdir -p "$mv"
    git clone -q https://github.com/open-mpc/mpc-vst-plugins.git "$MV"
fi
git -C "$MV" fetch -q origin
git -C "$MV" checkout -q --detach "$MV_REF"

if [ $# -gt 0 ]; then PORTS=("$@"); else
    PORTS=(); for d in "$REPO"/ports/*/; do PORTS+=("$(basename "$d")"); done
fi

for id in "${PORTS[@]}"; do
    PD="$REPO/ports/$id"
    [ -f "$PD/vst.json" ] || { echo "no such port: $id" >&2; exit 1; }
    echo
    echo "========== $id"
    eval "$(python3 "$REPO/tools/port_vars.py" "$PD")"

    # 1. upstream module source, pinned to the commit the release is built from
    "$REPO/tools/fetch-upstream.sh" "$id"

    # 2. skin, params.h, pluginlist-entry.xml (shadow_art is the artwork renderer gen_vst.py runs)
    docker run --rm -u "$U" -v "$REPO":/w -v "$MV":/mv:ro -w "/w/ports/$id" "$ARTIMG" sh -c \
        'mkdir -p build && gcc -O2 -I/mv/tools/vendor/force-shadow/tools -o build/shadow_art /mv/tools/shadow_art.c -lm'
    docker run --rm -u "$U" -e HOME=/tmp -v "$REPO":/w -v "$MV":/mv:ro -w "/w/ports/$id" "$PYIMAGE" sh -c \
        "pip install -q --no-warn-script-location --target /tmp/p pillow >/dev/null 2>&1; \
         PYTHONPATH=/tmp/p python3 /mv/tools/gen_vst.py '/w/ports/$id/vst.json'"
    SKIN="$PD/build/skin/$VENDOR - VST - $NAME"
    [ -f "$SKIN/Plugin Skins/TUI.json" ] || { echo "skin was not generated: $SKIN" >&2; exit 1; }

    # 3. the plugin itself
    PICKED_ADAPTER="$ADAPTER"   # from vst.json ("adapter"), not gen_vst's guess (it only knows "schwung")
    eval "$(python3 "$MV/tools/gen_vst.py" "$PD/vst.json" --shell)"
    ADAPTER="$PICKED_ADAPTER"
    ADAPTER_SRC="$REPO/adapters/$ADAPTER/${ADAPTER}_engine.c"
    [ -f "$ADAPTER_SRC" ] || { echo "missing $ADAPTER_SRC" >&2; exit 1; }
    export CFLAGS CFLAGS_ARM CFLAGS_A64 LIBS SOURCES SO ADAPTER_SRC U NAME
    export OUT="ports/$id/build"
    case "$TARGET" in armv7) export TARGET_FLAGS="$CFLAGS_ARM" ;; aarch64) export TARGET_FLAGS="$CFLAGS_A64" ;; esac
    docker run --rm --platform "$PLAT" -u "$U" -v "$REPO":/w -v "$MV":/mv:ro -v "$ADAPTER_SRC":/src/adapter.c:ro \
        -e SOURCES -e CFLAGS -e LIBS -e SO -e NAME -e TARGET_FLAGS -e OUT \
        -w /w "$IMG" bash -euc '
        mkdir -p "$OUT"
        case "$SOURCES" in *.cpp*|*.cc*|*.cxx*) CXX=1 ;; *) CXX=0 ;; esac
        XF=""; [ -n "${TARGET_FLAGS:-}" ] && XF="$TARGET_FLAGS"
        if [ "$CXX" = 0 ]; then
            gcc -O2 -Wall -Wextra -Wno-unused-parameter -fPIC -shared -fvisibility=hidden -std=gnu11 \
                $CFLAGS $XF -I"$OUT" -I/mv/wrapper $SOURCES /src/adapter.c /mv/wrapper/vst2_wrap.c \
                $LIBS -lpthread -ldl -Wl,--no-undefined -o "$OUT/$SO"
        else
            OBJS=""
            for f in $SOURCES; do
                o="$OUT/${f//\//_}.o"
                case "$f" in
                    *.cpp|*.cc|*.cxx) g++ -O2 -Wall -Wextra -Wno-unused-parameter -fPIC -fvisibility=hidden -std=gnu++11 $CFLAGS $XF -I"$OUT" -I/mv/wrapper -c "$f" -o "$o" ;;
                    *) gcc -O2 -Wall -Wextra -Wno-unused-parameter -fPIC -fvisibility=hidden -std=gnu11 $CFLAGS $XF -I"$OUT" -I/mv/wrapper -c "$f" -o "$o" ;;
                esac
                OBJS="$OBJS $o"
            done
            gcc -O2 -Wall -Wextra -Wno-unused-parameter -fPIC -fvisibility=hidden -std=gnu11 -I"$OUT" -c /mv/wrapper/vst2_wrap.c -o "$OUT/vst2_wrap.o"
            gcc -O2 -Wall -Wextra -fPIC -fvisibility=hidden -std=gnu11 -I"$OUT" -I/mv/wrapper -c /src/adapter.c -o "$OUT/adapter.o"
            g++ -O2 -shared -fPIC -fvisibility=hidden $OBJS "$OUT/vst2_wrap.o" "$OUT/adapter.o" $LIBS -lpthread -ldl -Wl,--no-undefined -o "$OUT/$SO"
        fi
        strip "$OUT/$SO"
        echo "built $OUT/$SO: $(stat -c %s "$OUT/$SO") bytes, highest glibc $(readelf -V "$OUT/$SO" | grep -o "GLIBC_[0-9.]*" | sort -uV | tail -1)"
    ' || exit 1
    [ "${only:-}" = 1 ] && continue

    # 4. package
    XTRA=(); [ -d "$REPO/licenses/$id" ] && XTRA=(--extra "$REPO/licenses/$id:LICENSES")
    UF=(); [ -f "$PD/user-files.json" ] && UF=(--user-files "$PD/user-files.json")
    UD=(); for d in $USER_DATA; do UD+=(--user-data "$d"); done
    python3 "$MV/tools/release.py" \
        --so "$PD/build/$SO" --skin "$SKIN" --entry "$PD/build/pluginlist-entry.xml" \
        --version "$VERSION" --id "schwung-$id" --repo "$RELEASE_REPO" --license "$LICENSE" \
        --about "$ABOUT" \
        "${UD[@]+"${UD[@]}"}" "${UF[@]+"${UF[@]}"}" "${XTRA[@]+"${XTRA[@]}"}" \
        -o "$DIST"
done

echo
echo "done. zips in $DIST; check one with: python3 $MV/tools/catalog_check.py <zip> --catalog"
