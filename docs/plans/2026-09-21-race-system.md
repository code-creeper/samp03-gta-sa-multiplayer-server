# Task: Multiplayer street races with /race
Date: 2026-09-21
Status: done

## Goal
`/race 1` puts everyone on the server onto a starting grid in the same car, counts 3-2-1-GO,
and sends them through the glowing GTA race checkpoints to a finish, with times and
placements. Built for two people on a LAN.

## Approach

### Engine - `filterscripts/races.pwn`
One race at a time, server-wide. Per the brief, starting a race pulls in *every* connected
player rather than opening a lobby.

State machine driven by a single repeating 1s timer (`RaceTick`), killed when the race ends
so no timer is orphaned:

    IDLE -> COUNTDOWN (3,2,1,GO via GameTextForPlayer) -> RUNNING -> IDLE

- `/race <n>`   start track n; everyone is entered
- `/races`      list the tracks
- `/raceleave`  drop out (others keep racing)
- `/racestop`   abort for everyone

Start: freeze each player with `TogglePlayerControllable(id, 0)`, spawn the track's vehicle,
`PutPlayerInVehicle`, and lay them out on a staggered grid - the file gives one start
position and heading, the script offsets racers +-2.5 m sideways and 4 m back per row. With
two players that is a safe side-by-side line on any road, and it means the track file does
not need a separate verified coordinate per grid slot.

Checkpoints use the natives directly:
`SetPlayerRaceCheckpoint(id, type, x,y,z, nextx,nexty,nextz, size)` - type 0 for a normal
checkpoint (draws the arrow to the next one), type 1 for the finish. `OnPlayerEnterRaceCheckpoint`
advances that player's index; past the last one on the last lap they finish. Lap tracking is
just "index wraps to 0, lap++", which is what makes the circuit tracks work.

Cleanup on finish, `/raceleave`, death and disconnect: disable the checkpoint, destroy the
vehicle we created, unfreeze. Timing via `GetTickCount()` deltas; placement is a finisher
counter.

`OnPlayerCommandText` returns 0 for anything it does not handle, per the dispatch rule in
CLAUDE.md, so `cheats` and `base` commands keep working.

### Track data - `scriptfiles/races/*.txt`, loaded at runtime
Data files rather than arrays compiled into the .pwn, for one specific reason: these tracks
are *recreations*, so some checkpoint will land somewhere awkward. A text file means nudging
it and `reloadfs races` - no rebuild. It also matches how `grandlarc` already loads its
vehicles from `scriptfiles/`.

Format, parsed with `strtok` from `gl_common.inc`:

    name Lowrider Race
    vehicle 536
    laps 1
    start 2500.0,-1680.0,13.5,90.0
    cp 2600.0,-1700.0,13.5,15.0

### Where the coordinates come from
Not typed from memory. `scriptfiles/vehicles/*.txt` holds 1773 hand-placed parked-car
positions - every one is a real on-road spot with correct ground-level Z. A build script
takes a rough waypoint loop I define per track and **snaps each waypoint to the nearest real
parked-car coordinate**, so every checkpoint is guaranteed to sit on a road at a valid
height. The script then checks the route: no gap under 60 m or over 900 m, and no point
outside the track's region.

Six tracks, spread across the map so there is something to race in each city:

| # | Track | Area | Car |
|---|---|---|---|
| 1 | Lowrider Race | LS, Idlewood/Willowfield | 536 Blade |
| 2 | Little Loop | LS, short downtown loop | 429 Banshee |
| 3 | City Circuit | LS, downtown, 2 laps | 541 Bullet |
| 4 | Badlands | Red County / Whetstone | 495 Sandking |
| 5 | SF Fastlane | San Fierro streets | 451 Turismo |
| 6 | LV Ringroad | Las Venturas outer ring | 411 Infernus |

## Files to Change
- `filterscripts/races.pwn` / `.amx` (new) - the engine
- `scriptfiles/races/*.txt` (new) - six track files
- `tools/maketrack.py` (new) - the snap-to-road track builder, kept so tracks are rebuildable
- `server.cfg` - add `races` to the filterscripts line
- `COMMANDS.txt` - new race section

## Risks
- The tracks are recreations, not the original SP coordinates - same roads and areas, my
  routing. Editing a line in the track file is the fix.
- Snapping uses parked-car spots, which are often roadside or in car parks rather than
  mid-lane. Checkpoint radius is 15-20 m, comfortably covering that.
- Everyone on the server gets pulled into a race, by request. `/raceleave` is the way out.
- Vehicle headroom: 1781 static + up to 50 race cars, within the 2000 cap.
- Race cars are spawned per race and destroyed at the end; a crash mid-race would leak them
  until restart.

## Deviations
| Original Plan | What Happened | Why |
|---|---|---|
| Checkpoints as `Float:tCPX[]` inside the `E_TRACK` enum | Moved to plain `gCPX[track][cp]` globals | pawncc 3.10.10 will not index an array field of an enum struct - `gTracks[t][tCPX][n]` is a syntax error |
| Snap checkpoints to any position in the vehicle files | Land vehicles only; boats, aircraft, trains and trailers excluded | Models 453/473/484/493/454 are boats, so their positions are out on the water. The first build put Lowrider Race checkpoints at z=-0.3 in the sea |
| Drop the airport pools | Also dropped `ls_airport`/`lv_airport` from City Circuit and LV Ringroad | Those positions are parked aircraft inside fenced tarmac, which can make a leg undrivable |
| Start line = nearest road position behind checkpoint 1 | Same, but excluding the checkpoints themselves | The nearest road position to "just behind checkpoint 1" is checkpoint 1. Every track spawned the grid on top of its own first checkpoint with heading 0 |
| Pick the road position closest to each ring step | Added a minimum gap from the previously placed checkpoint | City Circuit put two checkpoints 29 m apart where the road bends away from the ideal circle |
| Tracks found in `scriptfiles/races/` | Added `races/tracks.txt` listing them | Pawn cannot enumerate a directory |
| Start a race for every connected player | Skip anyone in `PLAYER_STATE_NONE`, `SPECTATING` or `WASTED` | `grandlarc` runs city and skin selection with the player spectating; putting them in a car from there leaves them stuck with no controls |
| - | `new state` renamed to `pstate` | `state` is a reserved word in Pawn |
| - | Added a per-track listing to the startup log | Verifies the file parser end to end - names with spaces, car, laps, checkpoint count and start heading all show up in `server_log.txt` |
