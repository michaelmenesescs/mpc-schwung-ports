#!/usr/bin/env bash
# Fetch a port's upstream module source at the exact commit its release is built from.
#   tools/fetch-upstream.sh 4k-eq        -> .build/upstream/<dir>/ (ports/4k-eq/upstream.json)
# The commit is a full SHA, never a branch: the published release must be reproducible.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
id="${1:?usage: tools/fetch-upstream.sh <port id>}"
PD="$REPO/ports/$id"
meta="$PD/upstream.json"
[ -f "$meta" ] || { echo "$meta: no upstream.json" >&2; exit 1; }
read -r url commit dir < <(python3 - "$meta" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
print(d["repo"], d["commit"], d.get("dir") or d["repo"].split("/")[1])
EOF
)
dst="$REPO/.build/upstream/$dir"
if [ -d "$dst/.git" ]; then
    have="$(git -C "$dst" rev-parse HEAD 2>/dev/null || true)"
    if [ "$have" = "$commit" ]; then
        echo "== upstream $dir @ ${commit:0:10} (already fetched)"
        exit 0
    fi
    rm -rf "$dst"
fi
mkdir -p "$(dirname "$dst")" "$dst"
git -C "$dst" init -q
git -C "$dst" remote add origin "https://github.com/$url.git" 2>/dev/null || git -C "$dst" remote set-url origin "https://github.com/$url.git"
git -C "$dst" fetch -q --depth 1 origin "$commit"
git -C "$dst" checkout -q FETCH_HEAD
echo "== upstream $dir @ ${commit:0:10} ($url)"
