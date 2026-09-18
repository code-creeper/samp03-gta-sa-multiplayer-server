//
// Cheat/admin commands for SA-MP 0.3.7
// Every command requires RCON admin: /rcon login <password>
// Type /cheats in game for the command list.
//

#include <a_samp>
#include "../include/gl_common.inc"

#define CHEAT_MESSAGE_COLOR   0xFF9900AA
#define CHEAT_USAGE_COLOR     0xFFCC2299

#define GOD_HEALTH            99999.0

static bool:bPlayerGod[MAX_PLAYERS];

//------------------------------------------------

stock SendUsage(playerid, const usage[])
{
	SendClientMessage(playerid, CHEAT_USAGE_COLOR, usage);
	return 1;
}

//------------------------------------------------

stock NotAdmin(playerid)
{
	SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* You are not logged in as an admin. Use /rcon login <password>");
	return 1;
}

//------------------------------------------------

public OnFilterScriptInit()
{
	for(new i = 0; i < MAX_PLAYERS; i++) bPlayerGod[i] = false;

	SetTimer("GodModeTick", 1000, true);

	printf("\n--Cheats FS loaded. Type /cheats in game (RCON admin required).\n");
	return 1;
}

//------------------------------------------------

public OnPlayerConnect(playerid)
{
	bPlayerGod[playerid] = false;
	return 1;
}

//------------------------------------------------

public OnPlayerDisconnect(playerid, reason)
{
	bPlayerGod[playerid] = false;
	return 1;
}

//------------------------------------------------

forward GodModeTick();
public GodModeTick()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		if(!IsPlayerConnected(i) || !bPlayerGod[i]) continue;

		// Admin can lose god mode by logging out of RCON.
		if(!IsPlayerAdmin(i)) {
			bPlayerGod[i] = false;
			SetPlayerHealth(i, 100.0);
			continue;
		}

		SetPlayerHealth(i, GOD_HEALTH);

		new vid = GetPlayerVehicleID(i);
		if(vid != 0) SetVehicleHealth(vid, 1000.0);
	}
	return 1;
}

//------------------------------------------------

public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[128], tmp[128], Message[144];
	new idx;

	cmd = strtok(cmdtext, idx);

	//------------------------------------------ /cheats

	if(strcmp("/cheats", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "--- Cheat commands ---");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/hp [amt]  /armour [amt]  /god  /jetpack");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/cash [amt]  /setcash [amt]");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/wep (id) [ammo]  /guns  /noguns");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/veh (model) [c1] [c2]  /fix  /nos  /flip");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/tp (x) (y) (z)  /goto (id)  /get (id)");
		SendClientMessage(playerid, CHEAT_USAGE_COLOR, "/skin (id)  /weather (id)  /time (hour)");
		return 1;
	}

	//------------------------------------------ /hp

	if(strcmp("/hp", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new Float:amount = 100.0;

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) amount = floatstr(tmp);

		SetPlayerHealth(playerid, amount);

		format(Message, sizeof(Message), "* Health set to %.0f", amount);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /armour

	if(strcmp("/armour", cmd, true) == 0 || strcmp("/armor", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new Float:amount = 100.0;

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) amount = floatstr(tmp);

		SetPlayerArmour(playerid, amount);

		format(Message, sizeof(Message), "* Armour set to %.0f", amount);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /god

	if(strcmp("/god", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		if(bPlayerGod[playerid]) {
			bPlayerGod[playerid] = false;
			SetPlayerHealth(playerid, 100.0);
			SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* God mode OFF");
		} else {
			bPlayerGod[playerid] = true;
			SetPlayerHealth(playerid, GOD_HEALTH);
			SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* God mode ON");
		}
		return 1;
	}

	//------------------------------------------ /jetpack

	if(strcmp("/jetpack", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* Jetpack granted");
		return 1;
	}

	//------------------------------------------ /cash

	if(strcmp("/cash", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new amount = 100000;

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) amount = strval(tmp);

		GivePlayerMoney(playerid, amount);

		format(Message, sizeof(Message), "* Gave you $%d (total $%d)", amount, GetPlayerMoney(playerid));
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /setcash

	if(strcmp("/setcash", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /setcash (amount)");

		new amount = strval(tmp);

		ResetPlayerMoney(playerid);
		GivePlayerMoney(playerid, amount);

		format(Message, sizeof(Message), "* Money set to $%d", amount);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /wep

	if(strcmp("/wep", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /wep (weaponid 1-46) [ammo]");

		new weaponid = strval(tmp);
		if(weaponid < 1 || weaponid > 46) {
			return SendUsage(playerid, "/wep : weapon id must be 1-46");
		}

		new ammo = 5000;

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) ammo = strval(tmp);

		GivePlayerWeapon(playerid, weaponid, ammo);

		format(Message, sizeof(Message), "* Gave weapon %d with %d ammo", weaponid, ammo);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /guns

	if(strcmp("/guns", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		static const iGunPack[] = {
			4,    // knife
			24,   // desert eagle
			26,   // sawn-off shotgun
			28,   // micro smg
			31,   // m4
			34,   // sniper rifle
			35,   // rocket launcher
			16,   // grenade
			18,   // molotov
			42,   // fire extinguisher
			46    // parachute
		};

		for(new i = 0; i < sizeof(iGunPack); i++) {
			GivePlayerWeapon(playerid, iGunPack[i], 5000);
		}

		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* Full weapon pack granted");
		return 1;
	}

	//------------------------------------------ /noguns

	if(strcmp("/noguns", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		ResetPlayerWeapons(playerid);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* Weapons cleared");
		return 1;
	}

	//------------------------------------------ /veh

	if(strcmp("/veh", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /veh (model 400-611) [colour1] [colour2]");

		new model = strval(tmp);
		if(model < 400 || model > 611) {
			return SendUsage(playerid, "/veh : model must be 400-611");
		}

		new colour1 = -1, colour2 = -1;

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) colour1 = strval(tmp);

		tmp = strtok(cmdtext, idx);
		if(strlen(tmp)) colour2 = strval(tmp);

		new Float:x, Float:y, Float:z, Float:angle;
		GetPlayerPos(playerid, x, y, z);
		GetPlayerFacingAngle(playerid, angle);

		new vehicleid = CreateVehicle(model, x, y, z + 1.0, angle, colour1, colour2, 600);
		if(vehicleid == INVALID_VEHICLE_ID) {
			return SendUsage(playerid, "/veh : could not create vehicle (server limit reached)");
		}

		LinkVehicleToInterior(vehicleid, GetPlayerInterior(playerid));
		SetVehicleVirtualWorld(vehicleid, GetPlayerVirtualWorld(playerid));
		PutPlayerInVehicle(playerid, vehicleid, 0);

		format(Message, sizeof(Message), "* Spawned vehicle model %d (id %d)", model, vehicleid);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /fix

	if(strcmp("/fix", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new vehicleid = GetPlayerVehicleID(playerid);
		if(vehicleid == 0) {
			return SendUsage(playerid, "/fix : you are not in a vehicle");
		}

		RepairVehicle(vehicleid);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* Vehicle repaired");
		return 1;
	}

	//------------------------------------------ /nos

	if(strcmp("/nos", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new vehicleid = GetPlayerVehicleID(playerid);
		if(vehicleid == 0) {
			return SendUsage(playerid, "/nos : you are not in a vehicle");
		}

		AddVehicleComponent(vehicleid, 1010);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* NOS fitted");
		return 1;
	}

	//------------------------------------------ /flip

	if(strcmp("/flip", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new vehicleid = GetPlayerVehicleID(playerid);
		if(vehicleid == 0) {
			return SendUsage(playerid, "/flip : you are not in a vehicle");
		}

		new Float:angle;
		GetVehicleZAngle(vehicleid, angle);
		SetVehicleZAngle(vehicleid, angle);

		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, "* Vehicle flipped upright");
		return 1;
	}

	//------------------------------------------ /tp

	if(strcmp("/tp", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		new Float:x, Float:y, Float:z;

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /tp (x) (y) (z)");
		x = floatstr(tmp);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /tp (x) (y) (z)");
		y = floatstr(tmp);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /tp (x) (y) (z)");
		z = floatstr(tmp);

		new vehicleid = GetPlayerVehicleID(playerid);
		if(vehicleid != 0) SetVehiclePos(vehicleid, x, y, z);
		else SetPlayerPos(playerid, x, y, z);

		format(Message, sizeof(Message), "* Teleported to %.1f, %.1f, %.1f", x, y, z);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /goto

	if(strcmp("/goto", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /goto (playerid)");

		new id = strval(tmp);
		if(!IsPlayerConnected(id) || id == playerid) {
			return SendUsage(playerid, "/goto : bad player ID");
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(id, x, y, z);

		new vehicleid = GetPlayerVehicleID(playerid);
		if(vehicleid != 0) SetVehiclePos(vehicleid, x + 2.0, y, z);
		else SetPlayerPos(playerid, x + 2.0, y, z);

		SetPlayerInterior(playerid, GetPlayerInterior(id));
		SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(id));

		new iName[MAX_PLAYER_NAME];
		GetPlayerName(id, iName, sizeof(iName));

		format(Message, sizeof(Message), "* Teleported to %s(%d)", iName, id);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /get

	if(strcmp("/get", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /get (playerid)");

		new id = strval(tmp);
		if(!IsPlayerConnected(id) || id == playerid) {
			return SendUsage(playerid, "/get : bad player ID");
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);

		new vehicleid = GetPlayerVehicleID(id);
		if(vehicleid != 0) SetVehiclePos(vehicleid, x + 2.0, y, z);
		else SetPlayerPos(id, x + 2.0, y, z);

		SetPlayerInterior(id, GetPlayerInterior(playerid));
		SetPlayerVirtualWorld(id, GetPlayerVirtualWorld(playerid));

		new iName[MAX_PLAYER_NAME];
		GetPlayerName(id, iName, sizeof(iName));

		format(Message, sizeof(Message), "* Brought %s(%d) to you", iName, id);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /skin

	if(strcmp("/skin", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /skin (0-311)");

		new skinid = strval(tmp);
		if(skinid < 0 || skinid > 311) {
			return SendUsage(playerid, "/skin : id must be 0-311");
		}

		SetPlayerSkin(playerid, skinid);

		format(Message, sizeof(Message), "* Skin set to %d", skinid);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /weather

	if(strcmp("/weather", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /weather (0-45)");

		new weatherid = strval(tmp);
		if(weatherid < 0 || weatherid > 45) {
			return SendUsage(playerid, "/weather : id must be 0-45");
		}

		SetWeather(weatherid);

		format(Message, sizeof(Message), "* Weather set to %d", weatherid);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	//------------------------------------------ /time

	if(strcmp("/time", cmd, true) == 0)
	{
		if(!IsPlayerAdmin(playerid)) return NotAdmin(playerid);

		tmp = strtok(cmdtext, idx);
		if(!strlen(tmp)) return SendUsage(playerid, "Usage: /time (hour 0-23)");

		new hour = strval(tmp);
		if(hour < 0 || hour > 23) {
			return SendUsage(playerid, "/time : hour must be 0-23");
		}

		SetWorldTime(hour);

		format(Message, sizeof(Message), "* World time set to %d:00", hour);
		SendClientMessage(playerid, CHEAT_MESSAGE_COLOR, Message);
		return 1;
	}

	return 0;
}

//------------------------------------------------
