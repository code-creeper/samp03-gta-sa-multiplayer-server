//
// Multiplayer street races.
//
// /race <n> drops every player on the server onto a starting grid in the same car, counts
// 3-2-1-GO, and sends them round the track through the glowing race checkpoints.  Times and
// placings are announced as people cross the line.
//
// One race runs at a time.  Starting one pulls everybody in, which is what you want on a
// private server with a couple of people on it; /raceleave is the way out.
//
// Tracks live in scriptfiles/races/ as plain text and are listed in races/tracks.txt.  They
// are loaded at startup, so a bad checkpoint can be nudged in a text editor and picked up
// with "reloadfs races" - no recompile.  tools/maketrack.py regenerates them.
//

#include <a_samp>
#include "../include/gl_common.inc"

#define RACE_COLOR            0x33CCFFAA
#define RACE_USAGE_COLOR      0xFFCC2299
#define RACE_RESULT_COLOR     0xFFDD00AA

#define MAX_RACES             10
#define MAX_CHECKPOINTS       32
#define RACE_NAME_LEN         32

// Starting grid: two abreast, rows behind the start line.
#define GRID_PER_ROW          2
#define GRID_SIDE_SPACING     3.2
#define GRID_ROW_SPACING      5.0

#define RACE_IDLE             0
#define RACE_COUNTDOWN        1
#define RACE_RUNNING          2

enum E_TRACK
{
	tName[RACE_NAME_LEN],
	tVehicle,
	tLaps,
	Float:tStartX,
	Float:tStartY,
	Float:tStartZ,
	Float:tStartA,
	tCPCount
}

static gTracks[MAX_RACES][E_TRACK];

// Checkpoint tables live outside E_TRACK: the compiler will not index an array field of an
// enum struct, so these are plain [track][checkpoint] arrays.
static Float:gCPX[MAX_RACES][MAX_CHECKPOINTS];
static Float:gCPY[MAX_RACES][MAX_CHECKPOINTS];
static Float:gCPZ[MAX_RACES][MAX_CHECKPOINTS];
static Float:gCPSize[MAX_RACES][MAX_CHECKPOINTS];
static gTrackCount = 0;

static gRaceState = RACE_IDLE;
static gRaceTrack = -1;
static gRaceTimer = 0;
static gCountdown = 0;
static gRaceStartTick = 0;
static gFinishers = 0;

static bool:gInRace[MAX_PLAYERS];
static bool:gFinished[MAX_PLAYERS];
static gPlayerCP[MAX_PLAYERS];
static gPlayerLap[MAX_PLAYERS];
static gPlayerVeh[MAX_PLAYERS];

forward RaceTick();

//------------------------------------------------
// fread() hands back the line terminator as well, and strrest() would keep it.

stock TrimLine(line[])
{
	new len = strlen(line);
	while(len > 0 && line[len - 1] <= ' ') {
		line[len - 1] = EOS;
		len--;
	}
	return len;
}

//------------------------------------------------
// Pull four comma separated floats out of "x,y,z,w".

stock ParseQuad(const text[], &Float:a, &Float:b, &Float:c, &Float:d)
{
	new piece[32];
	new idx;

	idx = token_by_delim(text, piece, ',', 0);
	if(idx == (-1)) return 0;
	a = floatstr(piece);

	idx = token_by_delim(text, piece, ',', idx + 1);
	if(idx == (-1)) return 0;
	b = floatstr(piece);

	idx = token_by_delim(text, piece, ',', idx + 1);
	if(idx == (-1)) return 0;
	c = floatstr(piece);

	// Last field has no delimiter after it, so token_by_delim returns -1 having still
	// filled piece.  That is expected here, unlike the checks above.
	token_by_delim(text, piece, ',', idx + 1);
	d = floatstr(piece);
	return 1;
}

//------------------------------------------------

stock LoadTrackFile(const filename[], slot)
{
	new path[64];
	format(path, sizeof(path), "races/%s", filename);

	new File:handle = fopen(path, filemode:io_read);
	if(!handle) return 0;

	gTracks[slot][tVehicle] = 411;
	gTracks[slot][tLaps] = 1;
	gTracks[slot][tCPCount] = 0;
	format(gTracks[slot][tName], RACE_NAME_LEN, "Unnamed");

	new line[256];
	new keyword[20];
	new rest[128];
	new idx;
	new Float:a, Float:b, Float:c, Float:d;

	while(fread(handle, line, sizeof(line)) > 0)
	{
		TrimLine(line);
		if(line[0] == EOS || line[0] == ';') continue;

		idx = 0;
		keyword = strtok(line, idx);
		rest = strrest(line, idx);

		if(strcmp(keyword, "name", true) == 0) {
			format(gTracks[slot][tName], RACE_NAME_LEN, "%s", rest);
		}
		else if(strcmp(keyword, "vehicle", true) == 0) {
			new model = strval(rest);
			if(model >= 400 && model <= 611) gTracks[slot][tVehicle] = model;
		}
		else if(strcmp(keyword, "laps", true) == 0) {
			new laps = strval(rest);
			if(laps > 0) gTracks[slot][tLaps] = laps;
		}
		else if(strcmp(keyword, "start", true) == 0) {
			if(ParseQuad(rest, a, b, c, d)) {
				gTracks[slot][tStartX] = a;
				gTracks[slot][tStartY] = b;
				gTracks[slot][tStartZ] = c;
				gTracks[slot][tStartA] = d;
			}
		}
		else if(strcmp(keyword, "cp", true) == 0) {
			new n = gTracks[slot][tCPCount];
			if(n < MAX_CHECKPOINTS && ParseQuad(rest, a, b, c, d)) {
				gCPX[slot][n] = a;
				gCPY[slot][n] = b;
				gCPZ[slot][n] = c;
				gCPSize[slot][n] = (d > 0.0) ? d : 15.0;
				gTracks[slot][tCPCount] = n + 1;
			}
		}
	}
	fclose(handle);

	// A track with one checkpoint is not a race.
	if(gTracks[slot][tCPCount] < 2) return 0;
	return 1;
}

//------------------------------------------------

stock LoadTracks()
{
	new File:handle = fopen("races/tracks.txt", filemode:io_read);
	if(!handle) {
		print("  Races: scriptfiles/races/tracks.txt not found - no tracks loaded.");
		return 0;
	}

	new line[128];
	gTrackCount = 0;

	while(fread(handle, line, sizeof(line)) > 0)
	{
		TrimLine(line);
		if(line[0] == EOS || line[0] == ';') continue;
		if(gTrackCount >= MAX_RACES) break;
		if(LoadTrackFile(line, gTrackCount)) gTrackCount++;
		else printf("  Races: could not load track '%s'", line);
	}
	fclose(handle);
	return gTrackCount;
}

//------------------------------------------------

stock FormatRaceTime(ms, out[], size)
{
	new mins = ms / 60000;
	new secs = (ms % 60000) / 1000;
	new hund = (ms % 1000) / 10;
	format(out, size, "%d:%02d.%02d", mins, secs, hund);
	return 1;
}

//------------------------------------------------
// Everything a player is holding on to from a race, handed back.

stock ClearRacer(playerid, bool:destroy_vehicle)
{
	if(IsPlayerConnected(playerid)) {
		DisablePlayerRaceCheckpoint(playerid);
		TogglePlayerControllable(playerid, 1);
	}
	if(destroy_vehicle && gPlayerVeh[playerid] != INVALID_VEHICLE_ID) {
		DestroyVehicle(gPlayerVeh[playerid]);
	}
	gPlayerVeh[playerid] = INVALID_VEHICLE_ID;
	gInRace[playerid] = false;
	gFinished[playerid] = false;
	gPlayerCP[playerid] = 0;
	gPlayerLap[playerid] = 0;
	return 1;
}

//------------------------------------------------

stock ShowRaceCheckpoint(playerid)
{
	new t = gRaceTrack;
	if(t < 0) return 0;

	new cp = gPlayerCP[playerid];
	new last = gTracks[t][tCPCount] - 1;
	new bool:is_final = (cp == last && gPlayerLap[playerid] == gTracks[t][tLaps] - 1);

	if(is_final) {
		// Type 1 is the chequered finish marker - no arrow, nothing after it.
		SetPlayerRaceCheckpoint(playerid, 1,
			gCPX[t][cp], gCPY[t][cp], gCPZ[t][cp],
			0.0, 0.0, 0.0,
			gCPSize[t][cp]);
	} else {
		new nxt = (cp == last) ? 0 : cp + 1;
		// Type 0 draws the arrow leaning towards the next checkpoint.
		SetPlayerRaceCheckpoint(playerid, 0,
			gCPX[t][cp], gCPY[t][cp], gCPZ[t][cp],
			gCPX[t][nxt], gCPY[t][nxt], gCPZ[t][nxt],
			gCPSize[t][cp]);
	}
	return 1;
}

//------------------------------------------------
// Grid slots run two abreast, back from the start line along its heading.

stock PlaceOnGrid(playerid, slot)
{
	new t = gRaceTrack;
	new Float:ang = gTracks[t][tStartA];

	new Float:fwd_x = -floatsin(ang, degrees);
	new Float:fwd_y =  floatcos(ang, degrees);
	new Float:right_x = floatcos(ang, degrees);
	new Float:right_y = floatsin(ang, degrees);

	new row = slot / GRID_PER_ROW;
	new col = slot % GRID_PER_ROW;
	new Float:side = (float(col) - (float(GRID_PER_ROW) - 1.0) / 2.0) * GRID_SIDE_SPACING;
	new Float:back = float(row) * GRID_ROW_SPACING;

	new Float:x = gTracks[t][tStartX] + right_x * side - fwd_x * back;
	new Float:y = gTracks[t][tStartY] + right_y * side - fwd_y * back;
	new Float:z = gTracks[t][tStartZ] + 0.5;

	new veh = CreateVehicle(gTracks[t][tVehicle], x, y, z, ang, -1, -1, -1);
	gPlayerVeh[playerid] = veh;

	SetPlayerInterior(playerid, 0);
	SetPlayerPos(playerid, x, y, z);
	SetPlayerFacingAngle(playerid, ang);
	if(veh != INVALID_VEHICLE_ID) PutPlayerInVehicle(playerid, veh, 0);
	SetCameraBehindPlayer(playerid);
	TogglePlayerControllable(playerid, 0);
	return 1;
}

//------------------------------------------------

stock EndRace(const reason[])
{
	if(gRaceTimer) {
		KillTimer(gRaceTimer);
		gRaceTimer = 0;
	}
	for(new i = 0; i < MAX_PLAYERS; i++) {
		if(gInRace[i]) ClearRacer(i, true);
	}
	gRaceState = RACE_IDLE;
	gRaceTrack = -1;
	gFinishers = 0;
	if(strlen(reason)) SendClientMessageToAll(RACE_COLOR, reason);
	return 1;
}

//------------------------------------------------

stock RacersRemaining()
{
	new n = 0;
	for(new i = 0; i < MAX_PLAYERS; i++) {
		if(gInRace[i] && !gFinished[i]) n++;
	}
	return n;
}

//------------------------------------------------

stock FinishRacer(playerid)
{
	new msg[144];
	new timetext[24];

	gFinishers++;
	gFinished[playerid] = true;
	FormatRaceTime(GetTickCount() - gRaceStartTick, timetext, sizeof(timetext));

	DisablePlayerRaceCheckpoint(playerid);

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	format(msg, sizeof(msg), "* %s finished #%d - %s", name, gFinishers, timetext);
	SendClientMessageToAll(RACE_RESULT_COLOR, msg);

	format(msg, sizeof(msg), "~y~#%d~n~~w~%s", gFinishers, timetext);
	GameTextForPlayer(playerid, msg, 5000, 1);

	if(RacersRemaining() == 0) EndRace("* Race over.");
	return 1;
}

//------------------------------------------------

stock StartRace(trackid, starterid)
{
	new msg[144];

	gRaceTrack = trackid;
	gRaceState = RACE_COUNTDOWN;
	gFinishers = 0;
	gCountdown = 2;

	new slot = 0;
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		if(!IsPlayerConnected(i) || IsPlayerNPC(i)) continue;

		// grandlarc runs its city and skin selection with the player spectating, so anyone
		// who has not spawned yet must be left alone - dropping them into a car from there
		// leaves them stuck with no controls.
		// "state" is a reserved word in Pawn.
		new pstate = GetPlayerState(i);
		if(pstate == PLAYER_STATE_NONE || pstate == PLAYER_STATE_SPECTATING || pstate == PLAYER_STATE_WASTED) {
			if(i == starterid) {
				SendClientMessage(i, RACE_COLOR, "* Spawn into the world first, then start the race.");
			}
			continue;
		}

		ClearRacer(i, true);
		gInRace[i] = true;
		gPlayerCP[i] = 0;
		gPlayerLap[i] = 0;
		PlaceOnGrid(i, slot);
		slot++;
	}

	if(slot == 0 || !gInRace[starterid]) {
		EndRace("");
		SendClientMessage(starterid, RACE_COLOR, "* Nobody could be put on the grid - race cancelled.");
		return 0;
	}

	new name[MAX_PLAYER_NAME];
	GetPlayerName(starterid, name, sizeof(name));
	format(msg, sizeof(msg), "* %s started a race: %s - %d lap(s), %d checkpoints. %d racing.",
		name, gTracks[trackid][tName], gTracks[trackid][tLaps], gTracks[trackid][tCPCount], slot);
	SendClientMessageToAll(RACE_COLOR, msg);
	SendClientMessageToAll(RACE_COLOR, "* Use /raceleave to drop out, /racestop to cancel it.");

	for(new i = 0; i < MAX_PLAYERS; i++) {
		if(gInRace[i]) GameTextForPlayer(i, "~r~3", 900, 1);
	}

	gRaceTimer = SetTimer("RaceTick", 1000, true);
	return 1;
}

//------------------------------------------------

public RaceTick()
{
	if(gRaceState == RACE_COUNTDOWN)
	{
		if(gCountdown > 0) {
			new text[8];
			format(text, sizeof(text), "~r~%d", gCountdown);
			for(new i = 0; i < MAX_PLAYERS; i++) {
				if(gInRace[i]) GameTextForPlayer(i, text, 900, 1);
			}
			gCountdown--;
			return 1;
		}

		gRaceState = RACE_RUNNING;
		gRaceStartTick = GetTickCount();
		for(new i = 0; i < MAX_PLAYERS; i++) {
			if(!gInRace[i]) continue;
			TogglePlayerControllable(i, 1);
			GameTextForPlayer(i, "~g~GO!", 1200, 1);
			ShowRaceCheckpoint(i);
		}
		return 1;
	}

	if(gRaceState == RACE_RUNNING && RacersRemaining() == 0) {
		EndRace("* Race over.");
	}
	return 1;
}

//------------------------------------------------

public OnPlayerEnterRaceCheckpoint(playerid)
{
	if(!gInRace[playerid] || gRaceState != RACE_RUNNING || gFinished[playerid]) return 0;

	new t = gRaceTrack;
	new last = gTracks[t][tCPCount] - 1;

	if(gPlayerCP[playerid] == last)
	{
		gPlayerLap[playerid]++;
		if(gPlayerLap[playerid] >= gTracks[t][tLaps]) {
			FinishRacer(playerid);
			return 1;
		}
		gPlayerCP[playerid] = 0;

		new msg[64];
		format(msg, sizeof(msg), "~w~Lap ~y~%d~w~/%d", gPlayerLap[playerid] + 1, gTracks[t][tLaps]);
		GameTextForPlayer(playerid, msg, 2000, 4);
	}
	else {
		gPlayerCP[playerid]++;

		new msg[32];
		format(msg, sizeof(msg), "~w~%d/%d", gPlayerCP[playerid], gTracks[t][tCPCount]);
		GameTextForPlayer(playerid, msg, 900, 6);
	}

	ShowRaceCheckpoint(playerid);
	return 1;
}

//------------------------------------------------

public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[20];
	new idx;
	new msg[144];

	cmd = strtok(cmdtext, idx);

	if(strcmp(cmd, "/races", true) == 0)
	{
		if(gTrackCount == 0) {
			SendClientMessage(playerid, RACE_COLOR, "* No tracks are loaded.");
			return 1;
		}
		SendClientMessage(playerid, RACE_COLOR, "* Tracks - start one with /race <number>");
		for(new i = 0; i < gTrackCount; i++) {
			format(msg, sizeof(msg), "   %d. %s - %d lap(s), %d checkpoints",
				i + 1, gTracks[i][tName], gTracks[i][tLaps], gTracks[i][tCPCount]);
			SendClientMessage(playerid, RACE_COLOR, msg);
		}
		return 1;
	}

	if(strcmp(cmd, "/race", true) == 0)
	{
		new arg[20];
		arg = strtok(cmdtext, idx);

		if(!strlen(arg) || !isNumeric(arg)) {
			SendClientMessage(playerid, RACE_USAGE_COLOR, "Usage: /race <number>   (see /races)");
			return 1;
		}
		if(gRaceState != RACE_IDLE) {
			SendClientMessage(playerid, RACE_COLOR, "* A race is already on. /racestop cancels it.");
			return 1;
		}

		new n = strval(arg);
		if(n < 1 || n > gTrackCount) {
			format(msg, sizeof(msg), "* No such track. Pick 1 to %d, or type /races.", gTrackCount);
			SendClientMessage(playerid, RACE_COLOR, msg);
			return 1;
		}

		StartRace(n - 1, playerid);
		return 1;
	}

	if(strcmp(cmd, "/raceleave", true) == 0)
	{
		if(!gInRace[playerid]) {
			SendClientMessage(playerid, RACE_COLOR, "* You are not in a race.");
			return 1;
		}

		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof(name));
		format(msg, sizeof(msg), "* %s left the race.", name);
		SendClientMessageToAll(RACE_COLOR, msg);

		ClearRacer(playerid, true);
		if(gRaceState != RACE_IDLE && RacersRemaining() == 0) EndRace("* Race over.");
		return 1;
	}

	if(strcmp(cmd, "/racestop", true) == 0)
	{
		if(gRaceState == RACE_IDLE) {
			SendClientMessage(playerid, RACE_COLOR, "* No race is running.");
			return 1;
		}
		EndRace("* The race was cancelled.");
		return 1;
	}

	// Anything else belongs to another script.
	return 0;
}

//------------------------------------------------

public OnPlayerDeath(playerid, killerid, reason)
{
	#pragma unused killerid
	#pragma unused reason

	if(gInRace[playerid] && !gFinished[playerid]) {
		SendClientMessage(playerid, RACE_COLOR, "* You wrecked out of the race.");
		ClearRacer(playerid, true);
		if(gRaceState != RACE_IDLE && RacersRemaining() == 0) EndRace("* Race over.");
	}
	return 0;
}

//------------------------------------------------

public OnPlayerConnect(playerid)
{
	gInRace[playerid] = false;
	gFinished[playerid] = false;
	gPlayerCP[playerid] = 0;
	gPlayerLap[playerid] = 0;
	gPlayerVeh[playerid] = INVALID_VEHICLE_ID;
	return 0;
}

//------------------------------------------------

public OnPlayerDisconnect(playerid, reason)
{
	#pragma unused reason

	if(gInRace[playerid]) {
		ClearRacer(playerid, true);
		if(gRaceState != RACE_IDLE && RacersRemaining() == 0) EndRace("* Race over.");
	}
	return 0;
}

//------------------------------------------------

public OnFilterScriptInit()
{
	for(new i = 0; i < MAX_PLAYERS; i++) {
		gInRace[i] = false;
		gFinished[i] = false;
		gPlayerCP[i] = 0;
		gPlayerLap[i] = 0;
		gPlayerVeh[i] = INVALID_VEHICLE_ID;
	}

	LoadTracks();
	printf("\n--Races FS loaded. %d track(s). Type /races in game.", gTrackCount);
	for(new i = 0; i < gTrackCount; i++) {
		printf("    %d. %s - car %d, %d lap(s), %d checkpoints, start %.1f %.1f %.1f @ %.0f",
			i + 1, gTracks[i][tName], gTracks[i][tVehicle], gTracks[i][tLaps],
			gTracks[i][tCPCount], gTracks[i][tStartX], gTracks[i][tStartY],
			gTracks[i][tStartZ], gTracks[i][tStartA]);
	}
	print(" ");
	return 1;
}

//------------------------------------------------

public OnFilterScriptExit()
{
	EndRace("");
	return 1;
}

//------------------------------------------------
