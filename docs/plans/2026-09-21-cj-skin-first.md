# Task: Put the CJ skin first in the character carousel
Date: 2026-09-21
Status: done

## Goal
Make CJ (skin model 0) the skin you land on when the character selection opens, so it can be
picked without scrolling and is what you get if you just hit Spawn.

## Approach
The carousel has no ordering logic of its own — it is simply the order of the
`AddPlayerClass()` calls in `grandlarc`'s `OnGameModeInit()`. The first call is class index 0,
which is where selection starts. Today that is skin 1; CJ is not in the list at all.

So: insert `AddPlayerClass(0, ...)` as the first entry, reusing the same spawn position,
facing angle and `-1` weapon slots as every other class in the block.

This has to be the gamemode and not a filterscript. A filterscript can call
`AddPlayerClass()`, but the classes it registers land wherever its load order puts them
relative to the gamemode's 45 — there is no way to force index 0 from there.

Every other class shifts up by one index. Nothing reads `classid`: `grandlarc`'s
`OnPlayerRequestClass()` ignores it and branches on city selection instead, and no
filterscript handles the callback except `worldlock`, which marks it `#pragma unused`. So the
shift is invisible.

## Files to Change
- `gamemodes/grandlarc.pwn` - one new `AddPlayerClass(0,...)` at the head of the class block
- `gamemodes/grandlarc.amx` - rebuild, committed per repo convention
- `COMMANDS.txt` - short note that CJ is the first skin

## Risks
- Gamemode change, so `reloadfs` will not pick it up. The server needs a full restart, and
  anyone connected is dropped. Worth doing when the server is idle.
- Class count goes 45 -> 46, well under the 320 limit.
- Skin 0 is the only skin with CJ's own animation set; the rest fall back to the generic ped
  set. That is the reason for the request and is a client-side property, nothing to configure.

## Deviations
| Original Plan | What Happened | Why |
|---|---|---|
| — | Implemented as planned. Compiled with the same 9 pre-existing warnings as before the change, and booted clean on a throwaway server on port 7778. | — |
