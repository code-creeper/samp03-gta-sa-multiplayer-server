//
// Locks the world to a fixed weather and time of day.
//
// The stock server drifts: gl_realtime pushes the real server clock into the game, and even
// without it the client clock keeps ticking until it rolls into night.  This script pins
// both and re-asserts them on a timer, so it stays clear daylight for as long as the
// server is up.
//
// /weather and /time in cheats.pwn talk to this script through CallRemoteFunction, so a
// change made in game becomes the new locked value instead of being undone on the next tick.
//

#include <a_samp>

// 11 = EXTRASUNNY_VEGAS.  Cloudless, fog-free, longest draw distance - best for flying.
#define LOCK_WEATHER          11

// 12:00.  Midday sun, no shadows long enough to darken buildings.
#define LOCK_HOUR             12
#define LOCK_MINUTE           0

// How often the lock is re-applied, in milliseconds.
#define LOCK_REFRESH_MS       30000

static gLockWeather = LOCK_WEATHER;
static gLockHour    = LOCK_HOUR;
static gLockMinute  = LOCK_MINUTE;
static gLockTimer   = 0;

forward WorldLockRefresh();
forward SetWorldLockWeather(weatherid);
forward SetWorldLockTime(hour);

//------------------------------------------------

stock ApplyWorldLockToPlayer(playerid)
{
	SetPlayerWeather(playerid, gLockWeather);
	SetPlayerTime(playerid, gLockHour, gLockMinute);
	TogglePlayerClock(playerid, 0);
	return 1;
}

//------------------------------------------------

stock ApplyWorldLock()
{
	SetWeather(gLockWeather);
	SetWorldTime(gLockHour);

	new i = 0;
	while(i != MAX_PLAYERS) {
		if(IsPlayerConnected(i)) ApplyWorldLockToPlayer(i);
		i++;
	}
	return 1;
}

//------------------------------------------------

public WorldLockRefresh()
{
	ApplyWorldLock();
	return 1;
}

//------------------------------------------------
// Called from cheats.pwn's /weather so the change sticks past the next refresh.

public SetWorldLockWeather(weatherid)
{
	if(weatherid < 0 || weatherid > 45) return 0;

	gLockWeather = weatherid;
	ApplyWorldLock();
	return 1;
}

//------------------------------------------------
// Called from cheats.pwn's /time.

public SetWorldLockTime(hour)
{
	if(hour < 0 || hour > 23) return 0;

	gLockHour = hour;
	gLockMinute = 0;
	ApplyWorldLock();
	return 1;
}

//------------------------------------------------

public OnFilterScriptInit()
{
	if(gLockTimer) KillTimer(gLockTimer);
	gLockTimer = SetTimer("WorldLockRefresh", LOCK_REFRESH_MS, 1);

	ApplyWorldLock();

	print("  World lock: weather and time of day are pinned.");
	return 1;
}

//------------------------------------------------

public OnFilterScriptExit()
{
	if(gLockTimer) {
		KillTimer(gLockTimer);
		gLockTimer = 0;
	}
	return 1;
}

//------------------------------------------------
// The gamemode sets its own weather on startup; take it back.

public OnGameModeInit()
{
	ApplyWorldLock();
	return 1;
}

//------------------------------------------------

public OnPlayerConnect(playerid)
{
	ApplyWorldLockToPlayer(playerid);
	return 1;
}

//------------------------------------------------

public OnPlayerRequestClass(playerid, classid)
{
	#pragma unused classid
	ApplyWorldLockToPlayer(playerid);
	return 1;
}

//------------------------------------------------

public OnPlayerSpawn(playerid)
{
	ApplyWorldLockToPlayer(playerid);
	return 1;
}

//------------------------------------------------
