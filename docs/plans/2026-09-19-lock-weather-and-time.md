# Task: Lock the world to permanent clear-sky daytime
Date: 2026-09-19
Status: done

## Goal
Pin the server to a cloudless sunny sky and midday light, and keep it pinned so it never
drifts back to night or bad weather while people are playing.

## Approach
- Drop `gl_realtime` from the `filterscripts` line in `server.cfg`. It is the thing that
  changes time during play: a 60-second timer that pushes the *real world* server clock into
  the game, so evenings and nights happen automatically.
- Add `filterscripts/worldlock.pwn`, which owns time and weather:
  - weather `11` (EXTRASUNNY_VEGAS) — the clearest sky in SA:MP, no cloud, no fog, best
    draw distance for flying
  - world time `12:00`
  - re-asserts both every 30 s, on `OnGameModeInit`, and per player on connect / class
    select / spawn, so the client clock cannot creep toward night
  - hides the in-game clock HUD, since the time no longer means anything
- Keep `/weather` and `/time` in `cheats.pwn` working: instead of being overwritten by the
  next re-assert tick, they now update the locked values via `CallRemoteFunction` into
  `worldlock`. So a change made in game is what stays.

## Files to Change
- `server.cfg` - remove `gl_realtime`, add `worldlock` to the filterscripts line
- `filterscripts/worldlock.pwn` (new) - the lock itself
- `filterscripts/worldlock.amx` (new) - build output, committed per repo convention
- `filterscripts/cheats.pwn` / `.amx` - `/weather` and `/time` update the lock
- `COMMANDS.txt` - note that the two commands are now permanent

## Risks
- `worldlock` must load *after* `cheats` is irrelevant, but it must load at all — if it is
  missing from `server.cfg` the `CallRemoteFunction` calls in `cheats.pwn` silently no-op and
  `/weather` reverts to stock behaviour. Not a crash, just a no-op.
- Weather 11 is Las Venturas colouring; it is clear everywhere but tints the sky slightly
  warmer than weather 1. Trivial to change via the `LOCK_WEATHER` define.
- Removing `gl_realtime` also removes the clock textdraw in the top-right corner. Intended.

## Deviations
| Original Plan | What Happened | Why |
|---|---|---|
| — | Implemented as planned; verified on a throwaway server on port 7778. | — |
