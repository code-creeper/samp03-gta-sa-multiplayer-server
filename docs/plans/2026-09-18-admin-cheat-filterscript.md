# Task: Add working "cheat" commands to the local SA-MP server
Date: 2026-09-18
Status: done

## Goal
Give the server RCON-gated admin commands (health, armour, money, weapons, vehicles,
teleport, jetpack, weather/time) so cheating works in-game, since SA-MP disables
single-player cheat codes and the stock grandlarc gamemode ships zero commands.

## Approach
- Install the Pawn compiler (none present on this machine):
  1. Try native Linux build: pawn-lang/compiler release `pawnc-3.10.11-linux.tar.gz`.
  2. Fallback if 32-bit libs are missing: the Windows `pawncc.exe` run via the
     already-installed Wine.
  Install into `tools/pawncc/` inside the server dir, not system-wide.
- Write `filterscripts/cheats.pwn`, a self-contained filterscript:
  - Every command gated behind `IsPlayerAdmin(playerid)` (RCON login).
  - Commands: /hp /armour /cash /wep /gun /veh /fix /nos /tp /goto /jetpack
    /god /weather /time /skin /tune, plus /cheats help list.
  - Uses only stock a_samp natives so it compiles against the bundled includes.
- Compile to `filterscripts/cheats.amx`.
- Add `cheats` to the `filterscripts` line in `server.cfg`.
- Restart `samp03svr` and confirm the filterscript loads cleanly in `server_log.txt`.

## Files to Change
- `tools/pawncc/*` - new, Pawn compiler (downloaded, local to server dir)
- `filterscripts/cheats.pwn` - new, the admin/cheat command filterscript
- `filterscripts/cheats.amx` - new, compiled output
- `server.cfg` - append `cheats` to the filterscripts list

## Usage after implementation
In-game: `/rcon login root` then e.g. `/cash 999999`, `/hp`, `/veh 411`.

## Risks
- Linux pawncc is 32-bit; may need `gcc-multilib` / `lib32stdc++6`. Wine fallback covers it.
- RCON password is `root` on a LAN-only server; fine locally, must change if ever
  exposed to the internet (`lanmode 1`, `announce 0` currently keep it private).
- Adding a filterscript changes server.cfg; original line is preserved in this plan:
  `filterscripts base gl_actions gl_property gl_realtime`

## Deviations
| Original Plan | What Happened | Why |
|---|---|---|
| Fetch pawnc 3.10.11 | Used 3.10.10 | 3.10.11 does not exist; 3.10.10 is the latest release |
| Wine fallback for pawncc | Not needed | 32-bit runtime libs already present; native Linux pawncc runs fine |
| Compile against bundled includes | Had to download includes too | Linux server package ships no Pawn stdlib, only gl_common/gl_spawns |
| Put includes in `include/` | Put them in `tools/include/` | Keeps the server's `include/` exactly as shipped; mirrors the Windows `pawno/include` layout |
| Restart samp03svr to verify | Verified in an isolated instance on port 7778 | The user's server was running in their own terminal; avoided killing it |
| /god /tune commands | /god kept, /tune dropped, /noguns and /flip added | /tune needs a component-id UI to be useful; /noguns and /flip are more practical |

## Follow-up (2026-09-18, user request)
Admin gate made optional. The per-command `IsPlayerAdmin` checks were replaced by a
`CanUseCheats()` helper controlled by `#define REQUIRE_ADMIN`, set to `0` so every
player can use the commands with no RCON login. The god-mode tick no longer revokes
god mode from non-admins. Both `IsPlayerAdmin` call sites remain in the source but
compile out. `COMMANDS.txt` updated to match. Rebuilt and load-tested on port 7778.

Trade-off accepted by the user: on a server reachable from the internet, any joining
player could spawn vehicles and use `/get` to move other players. Mitigated by
`lanmode 1` and `announce 0`; set `REQUIRE_ADMIN 1` before exposing the server.

## Notes
- Build any script with `tools/build.sh <path.pwn>`.
- One benign compile warning (239) on the `SetTimer` call: `funcname[]` is
  non-const in the official SA-MP include. Cosmetic, affects nothing.
- `server.cfg.bak` holds the pre-change config.
- Verified: `Loading filterscript 'cheats.amx'...` loads clean, 5 filterscripts total.
