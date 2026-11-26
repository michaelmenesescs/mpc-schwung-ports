# mpc-schwung-ports

[Schwung](https://github.com/charlesvestal/schwung) is the open DSP module platform for Ableton Move:
small C/C++ modules with a `plugin_api_v2` / `audio_fx_api_v2` entry point. This repository ports a
set of them to Akai's MPC OS standalone plugin host (MPC Live / Live II / One / X / Key 61 and the
Force, 32-bit ARM) as VST2 plugins with an MPC screen skin — the DSP code is compiled **unmodified**,
and a thin adapter presents it through the MPC wrapper's engine interface.

| release | module | upstream | licence |
|---|---|---|---|
| 4K EQ | British console EQ | [athousanddetails/schwung-4keq](https://github.com/athousanddetails/schwung-4keq) | GPL-3.0-only |
| Bus Driver | drum-bus glue | [legsmechanical/schwung-busdriver](https://github.com/legsmechanical/schwung-busdriver) | MIT |
| HUSH ONE | SH-101 style bass mono synth | [charlesvestal/schwung-hush1](https://github.com/charlesvestal/schwung-hush1) | MIT |
| Junologue Chorus | Juno-60 chorus | [charlesvestal/schwung-junologue-chorus](https://github.com/charlesvestal/schwung-junologue-chorus) | MIT |
| Midiverb | Alesis Midiverb / Midifex / Midiverb II (needs your own ROMs) | [charlesvestal/schwung-midiverb](https://github.com/charlesvestal/schwung-midiverb) | GPL-3.0-only |
| PSX Verb | PlayStation 1 SPU reverb | [charlesvestal/schwung-psxverb](https://github.com/charlesvestal/schwung-psxverb) | MIT |
| TapeDelay | tape delay | [charlesvestal/schwung-space-delay](https://github.com/charlesvestal/schwung-space-delay) | MIT |
| TAPESCAM | tape saturation and degradation | [charlesvestal/schwung-tapescam](https://github.com/charlesvestal/schwung-tapescam) | MIT |

Releases are the zips in [Releases](../../releases): `<Name>-<version>-mpc-armv7.zip`. Unzip, copy
`portable/<Vendor> - VST - <Name>/` into `VST2 Plugins/` on a drive (MPC OS 3.10.1 and later, with
External Plugin Support on in Preferences, Enhancements) and restart MPC, or run `install.sh` on the
device from a root shell. `INSTALL.md` inside the zip covers both.

`schwung-midiverb` ships **no ROMs**: the effect programs live in the units' EPROMs, so you dump your
own and drop the files in the plugin's `roms/` folder. A unit without its ROM passes audio through.

## How a port is built

```
ports/<id>/vst.json       name, vendor, uid, version, the module's sources, cflags, adapter
ports/<id>/module.json    the parameter list read from the module (skin + params.h source)
ports/<id>/upstream.json  upstream repo and the exact commit the release is built from
ports/<id>/user-files.json   (midiverb) the ROMs the user must supply
adapters/schwung/         plugin_api_v2 (instruments) -> mpc_engine_t
adapters/schwungfx/       audio_fx_api_v2 (effects)   -> mpc_engine_t
tools/fetch-upstream.sh   clone the pinned upstream source into .build/upstream/
tools/test-port.sh        offline x86 test under ASan: params, audio, chunks, threads
build.sh                  skin + params.h + compile + package, in Docker
```

```sh
./build.sh                 # every port -> dist/*.zip
./build.sh 4k-eq midiverb  # just these
tools/test-port.sh 4k-eq   # offline host test before it goes near a device
```

The wrapper (`wrapper/vst2_wrap.c`, `wrapper/engine.h`), the stock skin generator
(`tools/gen_vst.py`) and the packager (`tools/release.py`) come from
[open-mpc/mpc-vst-plugins](https://github.com/open-mpc/mpc-vst-plugins) at the commit pinned in
`build.sh`. Gen1 builds use `arm32v7/gcc:11-bullseye` (glibc 2.31, so at most `GLIBC_2.29`
symbols — MPC OS 2.x needs ≤ 2.32, MPC OS 3.x has 2.39).

## Licences

The glue in this repository (adapters, build scripts, port definitions, generated skins) is MIT —
see [LICENSE](LICENSE). The DSP modules keep their own licences; see [NOTICE.md](NOTICE.md). Each
upstream licence file, and the module's own NOTICE/THIRD_PARTY notices, are copied verbatim into
`licenses/<id>/` and shipped inside the release zip as
`portable/<Vendor> - VST - <Name>/LICENSES/`.

For the GPL ports that means the corresponding source is: the upstream module at the commit in
`ports/<id>/upstream.json`, the wrapper and tools at `MV_REF` in `build.sh`, and the adapter and
port definition in this repository — with `./build.sh <id>` as the build.

## Thanks

To the module authors: athousanddetails, legsmechanical, Charles Vestal and the people whose work
the modules build on (thement/midiverb_emulator, Dusk Audio for 4K EQ, Peter Allwin for the Juno
chorus, cyrusasfa for TapeDelay), and to sd88me for mpc-vst-plugins, which this builds on.

Not affiliated with or endorsed by Akai, inMusic or Ableton. Installing plugins on an MPC is
unofficial: back up first, use at your own risk.
