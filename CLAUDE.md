# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A stock **SA-MP 0.3.7-R2-2-1 Linux dedicated server** for GTA: San Andreas, plus local
customization. It is a game server you configure and script, not an application you build.
`samp03svr` is a prebuilt closed-source binary — it is never compiled here. Only the Pawn
scripts are.

The one local addition so far is `filterscripts/cheats.pwn` (RCON-gated admin/cheat commands)
and the `tools/` toolchain that builds it. `COMMANDS.txt` is its player-facing reference.

## Commands

```sh
./tools/build.sh filterscripts/cheats.pwn   # compile any .pwn -> .amx next to it
./samp03svr                                 # run the server (reads ./server.cfg, cwd-sensitive)
```

`build.sh` wraps `pawncc` with the correct include paths. Calling `pawncc` directly is
error-prone: its `-i` and `-o` flags take **no space** (`-iinclude`, not `-i include`), and it
needs `LD_LIBRARY_PATH` pointed at `tools/pawnc-3.10.10-linux/lib`.

Recompiling is not enough — the server loads `.amx` at startup. Either restart it, or use the
RCON command `reloadfs <name>` in game to hot-reload a single filterscript
(`loadfs` / `unloadfs` also exist; confirmed present in the `samp03svr` binary).

### There is no test suite

Nothing in this repo has automated tests, and there is no lint step. Verification means
starting the server and reading `server_log.txt` — a script with a compile-time-clean but
broken `.amx` shows up there as a load failure.

To verify a script **without killing a server the user is already running**, start a throwaway
instance on another port. Symlink the script dirs so you build against the same files:

```sh
mkdir -p /tmp/fstest && cd /tmp/fstest
ln -s <repo>/samp03svr .
for d in filterscripts gamemodes npcmodes scriptfiles include; do ln -s <repo>/$d .; done
sed -e 's/^port 7777$/port 7778/' <repo>/server.cfg > server.cfg
timeout 8 ./samp03svr; grep -E "Loading filterscript|Failed" server_log.txt
```

Caveat: `scriptfiles/` is shared and **written to at runtime** by `gl_property` (it appends to
`properties/*.txt` and maintains `properties/dbProperties.db`). Copy that directory instead of
symlinking it if the test could mutate state.

## Architecture

### Three script tiers, one process

- **Gamemode** (`gamemodes/`) — exactly one runs at a time, set by `gamemode0` in `server.cfg`
  (currently `grandlarc`). Owns spawns, teams, scoring, world setup.
- **Filterscripts** (`filterscripts/`) — independent add-on scripts listed on the
  `filterscripts` line of `server.cfg`. They are not modules the gamemode imports; the server
  loads each one separately and dispatches the *same* callbacks to all of them.
- **NPC modes** (`npcmodes/`) — bot clients, driven by `.rec` playback files in
  `npcmodes/recordings/`.

The key consequence: **callback return values control dispatch order.** Returning `0` from
`OnPlayerCommandText` in a filterscript passes the command down to the next script; returning
`1` swallows it. A new command handler must return `0` at the end of its handler chain or it
will silently break every other script's commands. `cheats.pwn` and `base.pwn` both follow this.

Filterscripts are also the right place for new features — they hot-reload via `reloadfs`,
where a gamemode change requires a full restart.

### Data-driven world state

`grandlarc` defines very little world content inline. It calls
`LoadStaticVehiclesFromFile()` (from `include/gl_common.inc`) across 17 of the 18 files in
`scriptfiles/vehicles/` (`sf_train.txt` is present but never loaded), totalling 1781 static
vehicles at boot. Format is one vehicle per line:
`model,x,y,z,angle,colour1,colour2 ;`. `gl_property` does the same for
`scriptfiles/properties/*.txt`.

This matters for headroom: SA-MP caps at 2000 vehicles, so only ~219 slots remain for anything
spawned at runtime.

### Shared helpers

`include/gl_common.inc` is the local utility library, included by the gamemode and most
filterscripts. It provides `strtok`/`strrest` (argument parsing), `isNumeric`,
`token_by_delim`, `IsKeyJustDown`, and the vehicle loader. `include/gl_spawns.inc` holds spawn
coordinate tables.

**There is no `sscanf` and no command processor library here.** Parse arguments with repeated
`strtok(cmdtext, idx)` calls, matching the style in `base.pwn` and `cheats.pwn`.

### Include layout — important gotcha

The Linux server package ships **no Pawn compiler and no standard includes**. They were added
here:

- `tools/include/` — the Pawn stdlib + SA-MP 0.3.7-R2-2-1 includes. This is what scripts
  compile against.
- `include/` — left exactly as the server shipped, only `gl_common.inc` and `gl_spawns.inc`.
- `tools/pawn-stdlib-master/`, `tools/samp-stdlib-*/`, `tools/*.tar.gz` — the untouched
  upstream downloads, kept deliberately for provenance.

Never put those raw extraction dirs on the include path. They contain `default.inc` and
`console.inc`, which are deliberately absent from `tools/include/`: `pawncc` auto-includes any
`default.inc` it finds, that pulls in `console.inc`, and its `print`/`printf` collide with the
natives `a_samp.inc` already declares (`error 021: symbol already defined`).

A benign `warning 239` on `SetTimer` calls is expected — `funcname[]` is non-const in the
official include. It is not worth fixing.

## Conventions

- **Commit the `.amx` alongside the `.pwn`.** The repo tracks build output for every script
  (30 `.amx` files) because the server cannot run without it. This is intentional, not an
  oversight.
- Match the surrounding Pawn style: tabs, `//---` separator comments between handlers,
  `static` for script-local state, `MAX_PLAYERS`-sized arrays cleared in `OnPlayerConnect`.
- Gate admin functionality behind `IsPlayerAdmin(playerid)` (RCON login), the only auth the
  server offers out of the box.
- `server.cfg` carries live local tuning and the RCON password; `server.cfg.bak` is the
  pre-customization copy.

## Planning

Per the user's global convention, implementation work gets a plan file in
`docs/plans/YYYY-MM-DD-<slug>.md`, written and approved *before* coding, then updated with a
Deviations table afterward. See the existing plan there for the expected shape.
