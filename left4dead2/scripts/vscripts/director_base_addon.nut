natsenko_meatwall <-
{
	// This is a surprise tool that'll help us later ;)
	globals =
	{
		meatwall_destined_to_spawn = false // turning true results in all tanks being replaced by meatwalls until this value is turned false.
		meatwall_enabled = true // turning to false results in meatwalls not spawning at all.
	}

	settings =
	{
		meatwall_chance = 10,
		meatwall_health = 9500,
		meatwall_speed = 0.3,
		meatwall_speed_ignited = 1.1,
		meatwall_faster_ignited = false,
		meatwall_drop_fire = false,
	}

	// Using the default settings from the relevant mod as a base.
	merasmus_settings =
	{
		merasmus_health = 13000
		merasmus_chance = 40 // irrelevant but for compatibility
		merasmus_bomb_range = 800 // irrelevant but for compatibility
		merasmus_speed = 1.15 // irrelevant but for compatibility
		merasmus_health_increment = 2000 
	}
	
	
	tanktank_settings =
	{
		tank_chance = 50 // percentile chance of a random tank becoming a panzer
		tank_health = 15000 // how much health the tank has (at base / easy)
		tank_has_turret = true // dictates if the tank should have an MG that it can fire at survivors
		tank_health_increment = 2000 // how much health the tank gains per difficulty level
		ignore_spawn_check = false
		tank_camps_incapped_players = false
		tank_speed = 1.125
		tank_cannon_cooldown = 4
		tank_attack_range = 999999
		tank_aggressive = true // makes the tank constantly drive toward players instead of waiting around as soon as it spots a player
		explosion_radius = 400
		projectile_damage = 15
	}

	function MeatwallThink()
	{
		if (!settings.meatwall_faster_ignited) { return }
		for (local meat; meat = Entities.FindByClassname(meat, "player"); )
		{
			meat.ValidateScriptScope()
			if ("IsMeatwall" in meat.GetScriptScope())
			{
				if (meat.IsOnFire())
				{
					NetProps.SetPropFloat(meat, "m_flLaggedMovementValue", settings.meatwall_speed_ignited)
				}
				else
				{
					NetProps.SetPropFloat(meat, "m_flLaggedMovementValue", settings.meatwall_speed)
				}
			}
		}
	}

	function OnGameEvent_round_start( params )
	{
		local meatwall_sounds = [
			"unused/meatwall_introduction.wav",
			"unused/MEATWALL.wav"
		]
		foreach (file in meatwall_sounds)
		{
			if (!IsSoundPrecached(file))
			{
				PrecacheSound(file)
			}
		}

		if (!IsModelPrecached("models/infected/meatwall.mdl"))
		{
			PrecacheModel("models/infected/meatwall.mdl")
		}
		SpawnEntityFromTable("info_target", {targetname = "natsenko_meatwall_soundtarget"})
		SpawnEntityFromTable("logic_timer", { RefireTime = 1, OnTimer = "!self,runscriptcode,DirectorScript.natsenko_meatwall.MeatwallThink()" })
	}

	function OnGameEvent_player_spawn( params )
	{
		if ("userid" in params)
		{
			if (params.userid)
			{
				local player = GetPlayerFromUserID(params.userid)

				if((player.GetZombieType() == 8 && (RandomInt(1, 100) <= settings.meatwall_chance || globals.meatwall_destined_to_spawn) && IsPlayerABot(player)) && globals.meatwall_enabled)
				{
					ConvertMeatwall(player)
					EntFire("worldspawn", "RunScriptCode", "DirectorScript.natsenko_meatwall.RevertToMerasmus(" + GetPlayerFromUserID(params.userid).GetEntityIndex().tostring() + ")", 1, null) // run compatibility check
				}
			}
		}
	}

	function ConvertMeatwall(player)
	{

		EmitAmbientSoundOn("unused/meatwall_introduction.wav", 1.0, 0, 100, Entities.FindByName(null, "natsenko_meatwall_soundtarget"))
		player.SetMaxHealth(settings.meatwall_health)
		player.SetHealth(settings.meatwall_health)
		player.ValidateScriptScope()
		NetProps.SetPropFloat(player, "m_flLaggedMovementValue", settings.meatwall_speed)
		player.GetScriptScope()["IsMeatwall"] <- 1
		SetFakeClientConVarValue(player, "name", "Meatwall")
		player.SetModel("models/infected/meatwall.mdl")
		NetProps.SetPropInt(player, "m_fFlags", NetProps.GetPropInt(player, "m_fFlags") & ~256);
		NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence("ACT_RUN"), 6);
		NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity("ACT_RUN"), 6);
		NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), 6);

		for (local leap; leap = Entities.FindByClassname(leap, "ability_throw"); )
        {
            local owner = NetProps.GetPropEntity(leap, "m_hOwnerEntity")
            if(IsMeatwall(owner))
            {
				// makes it so that converted tanks can't use abilities
				// NOTE: This doesn't work half of the time on 8Player servers for some odd reason.
				NetProps.SetPropFloatArray(leap, "m_nextActivationTimer", 999999, 0)
				NetProps.SetPropFloatArray(leap, "m_nextActivationTimer", Time() + 999999, 1)
				NetProps.SetPropInt(leap, "m_hasBeenUsed", 1)
            }
        }
	}

	function RevertToMerasmus(player_idx)
	{
		// most of this code is directly stolen anyway so it's only fair I add compatibility.
		local player = EntIndexToHScript(player_idx)
		// check if merasmus model is precached / exists
		if (IsModelPrecached("models/bots/merasmus/merasmus.mdl"))
		{
			if ( IsMerasmus(player) && IsMeatwall(player) )
			{
				// revert this entity back to the merasmus form
				// we don't have any special entities linked to the meatwall so we don't need to do much
				player.GetScriptScope()["IsMeatwall"] <- 0
				SetFakeClientConVarValue(player, "name", "Merasmus")
				player.SetModel("models/bots/merasmus/merasmus.mdl")
				NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence("ACT_RUN"), 6);
	    		NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity("ACT_RUN"), 6);
	    		NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), 6);
				player.SetMaxHealth(merasmus_settings.merasmus_health)
				player.SetHealth(merasmus_settings.merasmus_health)
				NetProps.SetPropFloat(player, "m_flLaggedMovementValue", merasmus_settings.merasmus_speed)
				StopAmbientSoundOn("unused/meatwall_introduction.wav", Entities.FindByName(null, "natsenko_meatwall_soundtarget"))
				Convars.SetValue( "tank_fist_radius", "15");
Convars.SetValue( "tank_attack_range", "50");
Convars.SetValue( "z_tank_throw_force", "800");
Convars.SetValue( "z_tank_footstep_shake_amplitude", "5");
Convars.SetValue( "z_tank_footstep_shake_radius", "750");
Convars.SetValue( "z_tank_footstep_shake_duration", "2");
Convars.SetValue( "z_tank_footstep_shake_interval", "0.4");
			}
		}
	}


function RevertToTankTank(player_idx)
	{
		// most of this code is directly stolen anyway so it's only fair I add compatibility.
		local player = EntIndexToHScript(player_idx)
		// check if merasmus model is precached / exists
		if (IsModelPrecached("models/wot/vehicles/german/hetzer.mdl"))
		{
			if ( IsTankTank(player) && IsMeatwall(player) )
			{
				// revert this entity back to the merasmus form
				// we don't have any special entities linked to the meatwall so we don't need to do much
				player.GetScriptScope()["IsMeatwall"] <- 0
		        SetFakeClientConVarValue(player, "name", "Jagdpanzer 38(t) Hetzer");
				player.SetModel("models/wot/vehicles/german/hetzer.mdl")
				NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence("ACT_RUN"), 6);
	    		NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity("ACT_RUN"), 6);
	    		NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), 6);
				StopAmbientSoundOn("unused/meatwall_introduction.wav", Entities.FindByName(null, "natsenko_meatwall_soundtarget"))
			}
		}
	}
	
	function IsMerasmus(player)
	{
		player.ValidateScriptScope()
		if ("is_merasmus" in player.GetScriptScope())
		{
			return true
		}
	}
	
	function IsTankTank(player)
	{
		player.ValidateScriptScope()
		if ("is_tank_tank" in player.GetScriptScope())
		{
			return true
		}
	}

	function IsMeatwall(player)
	{
		player.ValidateScriptScope()
		if("IsMeatwall" in player.GetScriptScope())
		{
			return true
		}
	}

	function OnGameEvent_player_death( params )
	{
		if ("userid" in params)
		{
			
		}
	}


function OnGameEvent_player_hurt(params)
	{
		if( ("userid" in params) && ("weapon" in params) && ("type" in params) )
		{
			local player = GetPlayerFromUserID(params.userid);
			// local tank = GetPlayerFromUserID(params.attacker);
			local tank_weapon = params.weapon;
			local type = params.type;
	
			if(tank_weapon == "tank_claw" && type == 128)
			{
			
			if (params.userid)
			{
				if (IsMeatwall(GetPlayerFromUserID(params.userid)))
				{
				
				// OLD
			
				// probably not accurate to the og tank punch impulse
				// local dir = player.GetOrigin() - tank.GetOrigin();
				// dir.z += 30;
				// dir.Norm();
				// local force_vec = dir * 800;

				// player.ApplyAbsVelocityImpulse(force_vec);
				
				// prevent standing up anim when landing
				local thinker = null;
				local thinker_name = "rotpi_thinker_" + params.userid;
				thinker = Entities.FindByName(thinker, thinker_name);
				
				if(thinker == null)
				{
					thinker = SpawnEntityFromTable("info_target", { targetname = thinker_name });
					
					if(thinker.ValidateScriptScope())
					{
						thinker.GetScriptScope()["rotpi_think"] <- function ()
						{
							// printl("test")
						
							//if we've landed
							if(NetProps.GetPropInt(player, "m_hGroundEntity") != -1)
							{
								// play anim, method discovered by Shadowysn
								local slot = 6;
								
								// works i guess, sequence duration is long enough to cover up the actual anim.
								// BUG: "shooting" layer anims will not play until this anim is finished
								local anim = NetProps.GetPropInt(player.GetActiveWeapon(), "m_isDualWielding") == 1 ? "ACT_IDLE_INCAP_ELITES" : "ACT_IDLE_INCAP_PISTOL";
								
								// this anim fits, but the actual anim plays right after and there doesn't seem to be a way to cancel it
								// local anim = "ACT_TERROR_INCAP_FROM_TONGUE";

								NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence(anim), slot);
								NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity(anim), slot);
								NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), slot);
								
								thinker.Kill();
							}
							
							return 0.01;
						}
						
						DoEntFire("!self", "RunScriptCode", "AddThinkToEnt(self, \"rotpi_think\")", 0.25, null, thinker);
					}
				}
			}
		}
				
				}
			}
				
	}


	function ParseSettings()
    {
        local SettingsFileName = "meatwall/config.cfg"
        local file = FileToString(SettingsFileName)

        local tData;
        local function SerializeSettings() {
            local sData = "{"
            foreach (key, val in settings) {
                if (type(val) == "string") {
                    val = "\"" + val + "\""
                } else if (type(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (type(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
        }
        if (tData = file){
            try {
                tData = compilestring("return " + tData)()
                local hasMissingKey = false
                foreach (key, val in settings){
                    if (key in tData){
                        settings[key] = tData[key]
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true
                    }
                }
                if (hasMissingKey)
                { SerializeSettings() }
            }
            catch (error) {
                SerializeSettings()
            }
        }
        else{
            SerializeSettings();
        }
    }

	// this is NOT AT ALL the optimal way to go about this. Duplicating the exact same function twice is a sin and I should be reprimanded for this.
	// However, I have been sleeping on this update for way too fucking long not to do this.
	function ParseMerasmusSettings()
	{
		local SettingsFileName = "merasmus/settings.cfg"
        local file = FileToString(SettingsFileName)

        local tData;
        local function SerializeSettings() {
            local sData = "{"
            foreach (key, val in merasmus_speed) {
                if (type(val) == "string") {
                    val = "\"" + val + "\""
                } else if (type(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (type(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
        }
        if (tData = file){
            try {
                tData = compilestring("return " + tData)()
                local hasMissingKey = false
                foreach (key, val in merasmus_settings){
                    if (key in tData){
                        settings[key] = tData[key]
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true
                    }
                }
                if (hasMissingKey)
                { SerializeSettings() }
            }
            catch (error) {
                SerializeSettings()
            }
        }
        else{
            SerializeSettings();
        }
	}
	
	
	// Shit i'm worse I DID IT THRICE LMAO
	// It Needs Fixes
	function ParseTankTankSettings()
	{
		local SettingsFileName = "hetzer_tank/config.cfg"
        local file = FileToString(SettingsFileName)

        local tData;
        local function SerializeSettings() {
            local sData = "{"
            foreach (key, val in merasmus_speed) {
                if (type(val) == "string") {
                    val = "\"" + val + "\""
                } else if (type(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (type(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
        }
        if (tData = file){
            try {
                tData = compilestring("return " + tData)()
                local hasMissingKey = false
                foreach (key, val in tanktank_settings){
                    if (key in tData){
                        settings[key] = tData[key]
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true
                    }
                }
                if (hasMissingKey)
                { SerializeSettings() }
            }
            catch (error) {
                SerializeSettings()
            }
        }
        else{
            SerializeSettings();
        }
	}
	
}
__CollectGameEventCallbacks(natsenko_meatwall)
natsenko_meatwall.ParseSettings()
natsenko_meatwall.ParseMerasmusSettings()