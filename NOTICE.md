# Third-party components

The plugin binaries in each release are compiled from the upstream modules below, **unmodified**, at
the pinned commit. Their licences govern the DSP code; this repository's MIT licence covers only the
glue (adapters, build scripts, port definitions, generated skins).

| catalog id | module | upstream (commit) | licence |
|---|---|---|---|
| `schwung-4k-eq` | 4K EQ | [athousanddetails/schwung-4keq](https://github.com/athousanddetails/schwung-4keq) @ `3493c9496b1df1b6fe6a6c5f495bcc61bdbf71aa` | GPL-3.0-or-later |
| `schwung-bus-driver` | Bus Driver | [legsmechanical/schwung-busdriver](https://github.com/legsmechanical/schwung-busdriver) @ `36b6788de7eb15e11a5072680b6fbf06c020a947` | MIT |
| `schwung-hush-one` | HUSH ONE | [charlesvestal/schwung-hush1](https://github.com/charlesvestal/schwung-hush1) @ `598ab90505f7f924d09ed83f47e46430218cd43b` | MIT |
| `schwung-junologue-chorus` | Junologue Chorus | [charlesvestal/schwung-junologue-chorus](https://github.com/charlesvestal/schwung-junologue-chorus) @ `0b1ecd9d09daad91b5726899bd5e4cfe3f97cf06` | MIT |
| `schwung-midiverb` | Midiverb | [charlesvestal/schwung-midiverb](https://github.com/charlesvestal/schwung-midiverb) @ `12077e909d933f09604756fa05ef7838f986deed` | GPL-3.0-only |
| `schwung-psx-verb` | PSX Verb | [charlesvestal/schwung-psxverb](https://github.com/charlesvestal/schwung-psxverb) @ `c8cc0423807cd784888a47003a39417759fc98ac` | MIT |
| `schwung-tapedelay` | TapeDelay | [charlesvestal/schwung-space-delay](https://github.com/charlesvestal/schwung-space-delay) @ `87e0cbf65cdb79933718e662552864d15080c714` | MIT |
| `schwung-tapescam` | TAPESCAM | [charlesvestal/schwung-tapescam](https://github.com/charlesvestal/schwung-tapescam) @ `e9ab1ae20aa780da23a9a284d7e95402f51d17e4` | MIT |

### 4K EQ: Dusk Audio

The 4K EQ DSP is **not** athousanddetails' work: their `schwung-4keq` module vendors the engine
unmodified from **[dusk-audio/dusk-audio-plugins](https://github.com/dusk-audio/dusk-audio-plugins)**
under `src/ported/`, licensed **GPL-3.0-or-later**. Every band law, the Brown and Black calibration
tables, the shared-stage pair corrections, the console nonlinearity and the fourteen factory programs
are Dusk Audio's; `schwung-4keq` adds only the Move shell around them, and this port only the MPC glue.

The upstream notices for that vendored code — the file-by-file table of what came from where — ship
inside the release zip as `LICENSES/THIRD_PARTY.md`, and `licenses/4k-eq/` in this repository
holds the same file. Because the engine is GPL-3.0-or-later, the catalog entry for 4K EQ is
`GPL-3.0-or-later` as well, and its complete source is public: the module at the pinned commit above,
the wrapper at the commit in `build.sh`, the adapter and port definition in this repository.

Each upstream licence file, plus its own NOTICE / THIRD_PARTY notices where the module has them, is
copied verbatim into `licenses/<id>/` and shipped inside the release zip as
`portable/<Vendor> - VST - <Name>/LICENSES/`.

## Plugin wrapper and skin generator

The VST2 wrapper (`wrapper/vst2_wrap.c`, `wrapper/engine.h`) and the skin generator
(`tools/gen_vst.py`, `tools/release.py`) come from
[open-mpc/mpc-vst-plugins](https://github.com/open-mpc/mpc-vst-plugins), MIT, © 2026 sd88me, at the
commit pinned in `build.sh` (`MV_REF`). They are used unmodified; the commit named there is the one
the releases are built with.

## MIDI/audio module API

The Schwung `plugin_api_v2` / `audio_fx_api_v2` headers the adapters compile against are the
modules' own copies (in the upstream trees above) and carry the upstream licence.

## No ROMs

`schwung-midiverb` contains no Alesis ROM images and never will: the effect algorithms live in the
units' EPROMs, which you must dump from your own hardware. See the port's `user-files.json`.
