#!/usr/bin/env python3
"""Print a port's build settings as shell assignments (build.sh evals this).

Reads ports/<id>/vst.json: the keys tools/gen_vst.py needs (name, vendor, uid, version, so, module,
adapter, effect, build) plus the catalog/release ones this repo adds:
    release_version  X.Y.Z of the release (default: from "version", the VST integer)
    license          SPDX id of the upstream module's licence
    about            one line for INSTALL.md and plugin.json
    user_data        folders inside the plugin folder that hold the user's own files (ROMs)
Standard library only.
"""
import json
import os
import sys


def main():
    pd = os.path.abspath(sys.argv[1])
    cfg = json.load(open(os.path.join(pd, "vst.json")))
    v = int(cfg.get("version", 0))
    version = cfg.get("release_version") or "%d.%d.%d" % (v // 1000, v // 100 % 10, v // 10 % 10)
    up = {}
    if os.path.exists(os.path.join(pd, "upstream.json")):
        up = json.load(open(os.path.join(pd, "upstream.json")))
    out = {
        "NAME": cfg["name"],
        "VENDOR": cfg["vendor"],
        "UID4": cfg["uid"],
        "SO": cfg["so"],
        "VERSION": version,
        "LICENSE": cfg.get("license", ""),
        "ABOUT": cfg.get("about", ""),
        "ADAPTER": cfg.get("adapter", "schwung"),
        "USER_DATA": " ".join(cfg.get("user_data", [])),
        "UPSTREAM_DIR": up.get("dir", ""),
    }
    for k, val in out.items():
        print("%s=%s" % (k, "'" + str(val).replace("'", "'\\''") + "'"))


if __name__ == "__main__":
    main()
