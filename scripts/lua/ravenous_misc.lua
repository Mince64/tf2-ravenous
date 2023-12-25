-------------
-- Math
-------------

-- Round a number
math.round = function(num, decimals)
	if (not decimals or decimals <= 0) then
		return math.floor(num + 0.5);
	else
		local mod = 10 ^ decimals;
		return math.floor((num * mod) + 0.5) / mod;
	end
end

-- Round to nearest divisible
math.rounddiv = function(num, div)
	local remainder = num % div;
	
	if (remainder == 0) then
		return num;
	elseif (remainder < div / 2) then
		return num - remainder;
	else
		return num + div - remainder;
	end
end

-- Get the integer value for an rgb value
math.rgbtoint = function(red, green, blue)
	return (red << 16) + (green << 8) + blue
end

-- Random float
math.randomfloat = function(m, n)
	if (m) then
		if (n) then
			if (n == m) then return m;
			elseif (m > n) then m, n = n, m; end -- n should be greater than m
			
			local dif  = n - m;
			local mod  = dif * math.random();

			return m + mod;
			
		else
			return m * math.random();
		end
	else
		return math.random();
	end
end

-------------
-- CEntity
-------------

-- Grab the CEntity table
local _ = Entity("info_target", false, false);
CEntity = getmetatable(_);
_:Remove();

-------------
-- Entity methods
-------------

function IsValidPlayer(ent)
	return IsValid(ent) and ent:IsPlayer();
end

function IsValidRealPlayer(ent)
	return IsValid(ent) and ent:IsRealPlayer();
end

function IsValidAlivePlayer(ent)
	return IsValid(ent) and ent:IsPlayer() and ent:IsAlive();
end

function IsValidAliveRealPlayer(ent)
	return IsValid(ent) and ent:IsRealPlayer() and ent:IsAlive();
end

-- Set entity attributes
CEntity.SetAttributeValues = function(self, attributes)
	if (IsValid(self)) then
		for attr, val in pairs(attributes) do
			self:SetAttributeValue(attr, val);
		end
	end
end

-- Set model scale over time
CEntity.SetModelScale = function(self, scale, over_time, increment)
	if (not IsValid(self)) then return; end

	if (over_time and over_time > 0) then
		if (not increment or increment <= 0) then increment = 0.01; end
		local current_scale = self.m_flModelScale;

		if (scale - current_scale == 0) then
			return;
		elseif (scale - current_scale < 0) then
			increment = -increment;
		end

		local exec_times    = math.floor(math.abs((scale - current_scale) / increment));
		local counter       = 0;
		timer.Create(over_time / exec_times, function()
			if (not IsValid(self)) then return; end

			counter = counter + 1;
			current_scale = current_scale + increment;

			if (counter == exec_times and current_scale ~= scale) then
				self.m_flModelScale = scale;
			else
				self.m_flModelScale = current_scale;
			end
		end, exec_times);
	else
		self.m_flModelScale = scale;
	end
end

-- Play a particle system and parent it to the entity
CEntity.PlayParentedParticle = function(self, particle, offset, remove_after, RemoveFunction)
	if (not IsValid(self)) then return; end

	particle = ents.CreateWithKeys("info_particle_system", {
		effect_name=particle, start_active=1,
		["$modules"]="fakeparent", ["$positiononly"]=1,
	}, true, true)

	local entity_origin = self:GetAbsOrigin();
	if (offset) then entity_origin = entity_origin + offset; end

	particle.m_vecOrigin = entity_origin;
	particle:SetFakeParent(self);
	particle:Start();

	timer.Create(remove_after, function()
		pcall(particle["Remove"], particle);
		if (RemoveFunction) then pcall(RemoveFunction); end
	end, 1);

	return particle;
end

-- Is this entity within volume?
CEntity.IsInBox = function(self, mins, maxs)
	if (not IsValid(self)) then return; end

	local origin = self:GetAbsOrigin();

	-- Verify arguments
	for key, val in pairs({mins.x, mins.y, mins.z}) do
		if (mins[key] > maxs[key]) then
			mins[key], maxs[key] = maxs[key], mins[key];
		elseif (mins[key] == maxs[key]) then
			return;
		end
	end

	-- Is entity within bounds?
	for key, val in pairs({origin.x, origin.y, origin.z}) do
		if (not (origin[key] > mins[key] and origin[key] < maxs[key])) then return false; end
	end

	return true;
end

-------------
-- Item methods
-------------

-- Hack to get item (not arms) modelname
CEntity.GetItemModelName = function(self)
	if (not IsValid(self) or not self:IsItem()) then return; end
	
	local wearable = Entity("tf_wearable", false, false);
	wearable.m_bInitialized = true;
	wearable.m_iItemDefinitionIndex = self.m_iItemDefinitionIndex;
	
	wearable:Activate();
	wearable:DispatchSpawn();
	
	local modelname = wearable.m_ModelName;
	wearable:Remove();
	
	return modelname;
end

-------------
-- Player methods
-------------

-- How many spells does this player have unlocked
CEntity.CountUnlockedSpells = function(self)
	if (not IsValidRealPlayer(self)) then return; end

	local playerdata = player_list[self:GetUserId()].upgrades_spell_data;

	local count = 0;
	for spell, data in pairs(playerdata) do
		if (data._id) then
			count = count + 1;
		end
	end

	return count;
end

-- Play a voiceline for Captain Kinky
CEntity.PlayKinkyVO = function(self, sound, ext, range1, range2, duration, toself)
	if (not IsValidRealPlayer(self)) then return; end

	local userid     = self:GetUserId();
	local playerdata = player_list[userid];

	if (not playerdata.kinky_speaking_vo) then
		if (range1 and range2) then
			if (toself) then self:PlaySoundToSelf(sound..math.random(range1, range2)..ext);
			else self:PlaySound(sound..math.random(range1, range2)..ext); end
		else
			if (toself) then self:PlaySoundToSelf(sound..".wav");
			else self:PlaySound(sound..".wav"); end
		end

		if (duration) then
			playerdata.kinky_speaking_vo = true;

			timer.Create(duration, function()
				if (not IsValid(self)) then return; end

				playerdata.kinky_speaking_vo = false;
			end, 1)
		end
	end
end

-- Play a sequence for this player's viewmodel
CEntity.PlayVMSequence = function(self, sequence, playbackrate, nextidle, nextattack)
	if (not IsValidRealPlayer(self)) then return; end
	
	local wep = self.m_hActiveWeapon
	if (not IsValid(wep)) then return; end
	
	local viewmodel = self.m_hViewModel[1] or self.m_hViewModel[2];
	if (not IsValid(viewmodel)) then return; end

	wep.m_flTimeWeaponIdle     = nextidle;
	wep.m_flNextPrimaryAttack  = nextattack;
	viewmodel.m_flPlaybackRate = playbackrate;
	viewmodel.m_flCycle        = 0.0;
	viewmodel.m_nSequence      = sequence;
end

-- Get player eye angles
CEntity.GetEyeAngles = function(self)
	if (IsValidPlayer(self)) then
		return Vector(self["m_angEyeAngles[0]"], self["m_angEyeAngles[1]"], 0);
	end
end

-- Get player eye position
CEntity.GetEyePos = function(self)
	if (not IsValidPlayer(self)) then return; end
	
	local eyepos = self:GetAbsOrigin();
	eyepos.z = eyepos.z + self["m_vecViewOffset[2]"];
	
	return eyepos
end

-- Check whether the passed player is in our FOV (not necessarily whether we can see them)
CEntity.IsPlayerInFOV = function(self, player)
	if (not IsValidAlivePlayer(self)) then return; end
	if (not IsValidAlivePlayer(player)) then return; end
	
	local tolerance    = 0.5736; -- cos(110/2)
	local eyepos       = self:GetEyePos();
	local eyefwd       = self:GetEyeAngles():GetForward();
	local playerorigin = player:GetAbsOrigin()
	
	-- We go eyepos -> origin because you're more likely to see the top of a player
	-- rather than their feet due to map geometry
	
	-- What can we see from [eyepos, origin) ?
	-- Checks target eyepos and center
	for i=1,2 do
		playerorigin.z = playerorigin.z + player["m_vecViewOffset[2]"] / i;
		delta = (playerorigin - eyepos):Normalize();
		
		if (eyefwd:Dot(delta) >= tolerance) then return true; end
	end
	
	-- Can we see target's origin?
	local delta = (player:GetAbsOrigin() - eyepos):Normalize();
	if (eyefwd:Dot(delta) >= tolerance) then return true; end
	
	-- Not in our FOV
	return false;
end

-- Get player velocity in the X and Y axes (no Z)
CEntity.GetXYVelocity = function(self)
	if (IsValidAlivePlayer(self)) then
		local vecvelocity = self.m_vecAbsVelocity;
		local a = math.abs(vecvelocity.x);
		local b = math.abs(vecvelocity.y);

		return math.round(math.sqrt(a^2 + b^2), 2);
	end
end

-- Is this player walking?
CEntity.IsWalking = function(self)
	if (IsValidAlivePlayer(self)) then
		if (self.movetype == MOVETYPE_WALK and (self.m_fFlags & FL_ONGROUND ~= 0)) then
			return self:GetXYVelocity() >= 130;
		end
	end
end

-- Is this player midair?
CEntity.IsMidair = function(self)
	if (IsValidAlivePlayer(self)) then
		return not (self.movetype == MOVETYPE_WALK and (self.m_fFlags & FL_ONGROUND ~= 0));
	end
end

-- Is this player Harry Potter?
CEntity.IsWizard = function(self)
	if (not IsValidRealPlayer(self)) then return false; end

	return (self.m_iTeamNum == TEAM_RED and
			self.m_iClass == TF_CLASS_ENGINEER and
			player_list[self:GetUserId()].wizard_type ~= WIZARD_NONE);
end

-- Is this player invulnerable?
CEntity.IsInvuln = function(self)
	if (not IsValidPlayer(self)) then return; end

	if (self:InCond(TF_COND_INVULNERABLE) or
		self:InCond(TF_COND_INVULNERABLE_CARD_EFFECT) or
		self:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) or
		self:InCond(TF_COND_INVULNERABLE_USER_BUFF)) then

		return true;
	end

	return false;
end

-- Get player's wearables
CEntity.GetWearables = function(self, getnames, getattributes)
	if (not IsValidPlayer(self)) then return; end
	
	local wearables    = ents.FindAllByClass("tf_wearable");
	local my_wearables = {};
	
	for index, wearable in pairs(wearables) do
		if (IsValid(wearable) and self == wearable.m_hOwnerEntity) then
			local key = getnames and wearable:GetItemName() or wearable;
			if (not getattributes) then
				table.insert(my_wearables, key);
			else
				table.insert(my_wearables, {key, wearable:GetAllAttributeValues()});
			end
		end
	end
	
	return my_wearables;
end

CEntity.GiveLoadout = function(self, cosmetics, weapons, otherclass, ignoreclass)
	if (not IsValidAlivePlayer(self) or
		(not ignoreclass and self.m_iClass ~= otherclass)) then return; end
	
	if (cosmetics) then
		-- Remove old ones
		for index, cosmetic in pairs(self:GetWearables(true)) do
			self:RemoveItem(cosmetic);;
		end
		
		-- Add new ones
		for index, cosmetic in pairs(cosmetics) do
			self:GiveItem(table.unpack(cosmetic));
		end
	end
	
	if (weapons) then
		for slot, weapon in pairs(weapons) do
			self:GiveItem(table.unpack(weapon));
		end
	end
end

-- Make bots ignore player for a time
CEntity.BotsIgnoreFor = function(self, seconds)
	if (not IsValidAliveRealPlayer(self)) then return; end
	if (not seconds) then seconds = 5; end
	
	self:SetAttributeValue("ignored by bots", 1);
	self.m_bForcedSkin = 1;
	self.m_nForcedSkin = 1;
	self:SetForcedTauntCam(1);
	self:AddCond(TF_COND_SPEED_BOOST, seconds);
	
	local wearables = self:GetWearables();
	for index, wearable in pairs(wearables) do
		wearable.m_iTeamNum = TEAM_BLUE;
	end
	
	local playerdata = player_list[self:GetUserId()]
	
	playerdata.heavy_botsignore_timer = timer.Create(seconds, function()
		if (not IsValid(self)) then return; end
		
		self:SetAttributeValue("ignored by bots", 0);
		self.m_bForcedSkin = 0;
		self.m_nForcedSkin = 0;
		self:SetForcedTauntCam(0);
		
		for index, wearable in pairs(wearables) do
			if (IsValid(wearable)) then
				wearable.m_iTeamNum = TEAM_RED;
			end
		end
	end, 1);
end

-- Player take damage simple
CEntity.TakeDamageSimple = function(self, damage, attacker, damagecustom)
	if (not IsValidPlayer(self) or not damage) then return; end
	if (not attacker) then attacker = self; end
	
	self:TakeDamage({
		Attacker         = attacker,
		Inflictor        = nil,
		Weapon           = nil,
		Damage           = damage,
		DamageType       = DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE,
		DamageCustom     = damagecustom,
		DamagePosition   = Vector(0,0,0),
		DamageForce      = Vector(0,0,0),
		ReportedPosition = Vector(0,0,0),
	});
end

-- Concise version of CEntity.ShowHudText
CEntity.ShowHudTextSimple = function(self, text, channel, x, y, clr, a, fadetime, holdtime)
	if (not IsValidPlayer(self)) then return; end
	
	alpha    = alpha    or 0;
	fadetime = fadetime or 0.25;
	holdtime = holdtime or 2;
	
	local r, g, b;
	if (clr and #clr == 3) then r, g, b = table.unpack(clr);
	else r, g, b = 255, 255, 255; end
	
	self:ShowHudText({
		channel = channel, x = x, y = y, effect = 0,
		r1 = r, g1 = g, b1 = b, a1 = a,
		r2 = r, g2 = g, b2 = b, a2 = a,
		fadeinTime = fadetime, fadeoutTime = fadetime,
		holdTime = holdtime, fxTime = 0,
	}, text);
end

CEntity.ShowHudDialogue = function(self, text, clr, fadein, sound_interval, sound_duration, fadeout, holdtime, fxtime)
	if (not IsValidPlayer(self)) then return; end
	
	fadein         = fadein or 0.025;
	sound_interval = sound_interval or 0.2;
	sound_duration = (sound_duration and sound_duration / sound_interval) or (#text * fadein) / sound_interval -- an approximation
	fadeout        = fadeout or 0.3;
	holdtime       = holdtime or 3;
	fxtime         = fxtime or 0.1;
	
	local r, g, b;
	if (clr and #clr == 3) then r, g, b = table.unpack(clr);
	else r, g, b = 255, 255, 255; end
	
	self:ShowHudText({
		channel = 0, x = -1, y = 0.3, effect = 2,
		r1 = r, g1 = g, b1 = b, a1 = 0,
		r2 = 0, g2 = 0, b2 = 0, a2 = 0,
		fadeinTime = fadein, fadeoutTime = fadeout,
		holdTime = holdtime, fxTime = fxtime,
	}, text);

	timer.Create(sound_interval, function()
		if (math.random(2) == 1) then
			self:PlaySoundToSelf("ui/panel_close.wav");
		else
			self:PlaySoundToSelf("ui/panel_open.wav");
		end
	end, sound_duration);
end

-- Roll a spell for this player
table.RandomChance = false;
CEntity.RollSpell = function(self, chancetable)
	if (not IsValidRealPlayer(self)) then return; end
	if (not chancetable or table.Count(chancetable) == 0) then return; end

	local spellbook = self:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
	if (not spellbook or spellbook.m_iClassname ~= "tf_weapon_spellbook") then return; end

	local tbl  = nil;

	-- Not allowed to roll custom spells
	if (not wizard_rng_rolls_custom_spells) then
		-- Strip custom spells from the chance table
		local sumchances = 0;
		tbl = {};
		for spell, chances in pairs(chancetable) do
			if (not spell_data[spell].is_custom) then
				tbl[spell] = chances;
				sumchances = sumchances + chances.roll_chance;
			end
		end

		-- The chance sum isn't correct as a result of removing custom spells
		if (sumchances ~= 1) then
			-- How much does each entry need to change?
			local difference = math.abs(1 - sumchances);
			local increment  = difference / table.Count(chancetable);

			-- Increment the table chances
			for spell, chances in pairs(tbl) do
				if (sumchances > 1) then
					chances.roll_chance = chances.roll_chance - increment;
				elseif (sumchances < 1) then
					chances.roll_chance = chances.roll_chance + increment;
				end
			end
		end
	-- Allowed to use custom spells
	else
		tbl = chancetable;
	end

	-- Choose a random spell
	local spell   = table.RandomChance(tbl);
	local charges = table.RandomChance(tbl[spell].charge_chances);

	-- Get our the spellbook's current spell
	local current_spell = spellbook.m_iSelectedSpellIndex;
	if (spellbook._m_iCustomSelectedSpellIndex) then
		current_spell = spellbook._m_iCustomSelectedSpellIndex;
	end

	-- Only select a spell if no spell or common -> rare
	if (current_spell < 0 or spellbook.m_iSpellCharges == 0 or
		(spell_data[current_spell].spell_type == SPELL_TYPE_COMMON and
		spell_data[spell].spell_type == SPELL_TYPE_RARE)) then

		SelectSpell(spellbook, spell, charges, 2.5, false, true);
	end
end

-------------
-- Generic functions
-------------

-- Get the footstep timer delay for temp ent spawning
function GetTimerDelay(class)
	if     ( class == TF_CLASS_SCOUT )        then return 0.15;
	elseif ( class == TF_CLASS_SOLDIER )      then return 0.3;
	elseif ( class == TF_CLASS_PYRO )         then return 0.25;
	elseif ( class == TF_CLASS_DEMOMAN )      then return 0.25;
	elseif ( class == TF_CLASS_HEAVYWEAPONS ) then return 0.2;
	elseif ( class == TF_CLASS_ENGINEER )     then return 0.25;
	elseif ( class == TF_CLASS_MEDIC )        then return 0.25;
	elseif ( class == TF_CLASS_SNIPER )       then return 0.25;
	elseif ( class == TF_CLASS_SPY )          then return 0.25;
	elseif ( class == TF_CLASS_CIVILIAN)      then return 0.3;
	else return 0.25;
	end
end

-- Create a temp ent footstep timer for this player
function CreateTETimer(player, tempent, keyvalues, soundtable, soundevery)
	if (not IsValidPlayer(player)) then return; end
	if (soundtable and not soundevery or soundevery == 0) then soundevery = 1; end

	local count  = 0
	return timer.Create(GetTimerDelay(player.m_iClass), function()
			if (not IsValid(player)) then return; end

			count = count + 1;

			if (soundtable and count % soundevery == 0) then
				player:PlaySoundToSelf(table.Random(soundtable));
			end

			local origin = player:GetAbsOrigin();
			origin.z = origin.z + 8;
			keyvalues.m_vecOrigin = origin;

			tempents.Send(tempent, keyvalues, nil);
		end, 0)
end

-- Damage all players within volume
function DamagePlayersInBox(player, mins, maxs, DamageFunction, OnDamageFunction)
	if (not IsValidAlivePlayer(player)) then return; end
	
	local player_origin = player:GetAbsOrigin();
	local entities = ents.FindInBox(player_origin+mins, player_origin+maxs);

	local enemy_count = 0;
	for index, ent in pairs(entities) do
		if (IsValidAlivePlayer(ent) and ent.m_iTeamNum ~= player.m_iTeamNum) then
			enemy_count = enemy_count + 1;
		end
	end

	local damage = 0;
	if (DamageFunction) then
		damage = DamageFunction(enemy_count);
	end

	for index, ent in pairs(entities) do
		if (IsValidAlivePlayer(ent) and ent.m_iTeamNum ~= player.m_iTeamNum) then
			ent:TakeDamage({
				Attacker = player,
				Inflictor = nil,
				Weapon = nil,
				Damage = damage,
				DamageType = DMG_BURN | DMG_PREVENT_PHYSICS_FORCE,
				DamageCustom = TF_DMG_CUSTOM_BURNING,
				DamagePosition = player_origin,
				DamageForce = Vector(0,0,0),
				ReportedPosition = player_origin,
			});
			if (OnDamageFunction) then OnDamageFunction(ent); end
		end
	end

	return enemy_count;
end

-- Cleanup heavy resources
function CleanupHeavyResources(player)
	if (not IsValidRealPlayer(player)) then return; end
	
	local userid = player:GetUserId();
	local playerdata = player_list[userid];
	
	player:SetForcedTauntCam(0);
	
	pcall(timer.Stop, playerdata.heavy_botsignore_timer);
	playerdata.heavy_botsignore_timer = nil;
end

-- Cleanup demo resources
function CleanupDemoResources(player)
	if (not IsValidRealPlayer(player)) then return; end
	
	local userid = player:GetUserId();
	local playerdata = player_list[userid];
	
	-- Reset view
	local ang = player:GetEyeAngles();
	ang.z = 0;
	player:SnapEyeAngles(ang);
	
	pcall(timer.Stop, playerdata.demo_drunk_timer);
	playerdata.demo_drunk_timer = nil;
end

-- Cleanup pyro resources
function CleanupPyroResources(player)
	if (not IsValidRealPlayer(player)) then return; end

	local userid = player:GetUserId();
	local playerdata = player_list[userid];

	local pyro_embers = playerdata.pyro_ember_particle;
	local pyro_timer  = playerdata.pyro_aoeblast_timer;

	if (pyro_embers) then
		pcall(pyro_embers["Remove"], pyro_embers);
		playerdata.pyro_ember_particle = nil;
	end

	if (pyro_timer) then
		pcall(timer.Stop, playerdata.pyro_aoeblast_timer);
		playerdata.pyro_aoeblast_timer = nil;
	end
end

-- Cleanup scout resources
function CleanupScoutResources(player)
	if (not IsValidRealPlayer(player)) then return; end

	local userid     = player:GetUserId();
	local playerdata = player_list[userid];

	-- Handle scout tempents
	if (playerdata.scout_tempent_timer or playerdata.scout_should_spawn_tempent) then
		playerdata.scout_should_spawn_tempent = false;
		pcall(timer.Stop, playerdata.scout_tempent_timer);
		playerdata.scout_tempent_timer = nil;
	end

	playerdata.scout_drinking_soda = false;
end

-- Stop Kinky's charge
function KinkyStopCharging(player)
	if (not IsValidRealPlayer(player)) then return; end

	local userid = player:GetUserId();
	local playerdata = player_list[userid];

	if (playerdata.kinky_charging) then
		if (playerdata.kinky_charge_timer) then
			pcall(timer.Stop, playerdata.kinky_charge_timer);
			playerdata.kinky_charge_timer = nil;
		end
		playerdata.kinky_charging     = false;
		playerdata.kinky_charge_time  = 0;

		player:SetAttributeValue("no_jump", 0);
		player:SetAttributeValue("no_duck", 0);
		timer.Create(0.5, function()
			if (not IsValid(player)) then return; end
			player:RemoveCond(TF_COND_CRITBOOSTED);
		end, 1);
	end
end

-- Ich trinke Cola und spiele Fortnite! Yipeeeeeeeee!
function PlayerDrinkSoda(player, defindex)
	if (not IsValidAliveRealPlayer(player)) then return; end
	
	local userid = player:GetUserId();
	local playerdata = player_list[userid];

	-- Bonk! Atomic Punch
	if ((defindex == 46 or defindex == 1145) and not player:IsMidair() and not
		playerdata.scout_drinking_soda) then

		playerdata.scout_drinking_soda = true;
		local move_speed_bonus = player:GetAttributeValue("move speed bonus") or 1;
		local health_regen     = player:GetAttributeValue("health regen") or 0;

		player:SetForcedTauntCam(1);

		timer.Create(0.5, function()
			if (not IsValid(player)) then return; end

			local player_pos = player:GetAbsOrigin();
			player_pos.z = player_pos.z + 70;
			util.ParticleEffect("utaunt_lightning_bolt", player_pos,
								Vector(0, player["m_angEyeAngles[1]"] + 180, 0));
			player:PlaySound("ambient/energy/zap1.wav");

			player.m_clrRender = math.rgbtoint(52, 116, 78);
			player:SetAttributeValues({
				["voice pitch scale"]=0.75, ["no double jump"]=1, ["health regen"]=20,
				["max health additive bonus"]=125, ["move speed penalty"]=0.875,
				["damage force reduction"]=0.5, ["damage bonus"]=1.25, ["fire rate penalty"]=1.15,
				["move speed bonus"]=1, ["hand scale"]=1.75,
			});

			timer.Create(8, function()
				if (not IsValid(player)) then return; end

				playerdata.scout_drinking_soda = false;
				player:SetForcedTauntCam(0);
				player.m_clrRender = math.rgbtoint(255, 255, 255);

				if (player.m_iClass == TF_CLASS_SCOUT) then
					player:SetAttributeValues({
						["voice pitch scale"]=1, ["no double jump"]=0, ["health regen"]=health_regen,
						["max health additive bonus"]=0, ["move speed penalty"]=1,
						["damage force reduction"]=1, ["damage bonus"]=1, ["fire rate penalty"]=1,
						["move speed bonus"]=move_speed_bonus, ["hand scale"]=1,
					});
				end
			end, 1);
		end, 1);

		timer.Create(1.2, function()
			if (not IsValid(player)) then return; end
			player:RemoveCond(TF_COND_PHASE);
		end, 1);

	-- Crit-a-Cola
	elseif (defindex == 163 and not player:IsMidair() and not
			playerdata.scout_drinking_soda) then

		playerdata.scout_drinking_soda = true;
		local move_speed = player:GetAttributeValue("move speed bonus") or 1;
		local jump_height = player:GetAttributeValue("increased jump height") or 1;
		local dmgfromcrits = player:GetAttributeValue("dmg taken from crit reduced") or 1;

		player:SetForcedTauntCam(1);

		timer.Create(0.5, function()
			if (not IsValid(player)) then return; end

			local player_pos = player:GetAbsOrigin();
			player_pos.z = player_pos.z + 70;
			util.ParticleEffect("utaunt_lightning_bolt", player_pos,
								Vector(0, player["m_angEyeAngles[1]"] + 180, 0));
			player:PlaySound("ambient/energy/zap1.wav");

			player:SetAttributeValues({
				["voice pitch scale"]=1.25, ["move speed bonus"]=1.5, ["fire rate bonus"]=0.8,
				["mult dmgtaken from melee"]=0.7, ["air dash count"]=8, ["increased jump height"]=1.8,
				["cancel falling damage"]=1, ["dmg taken from crit reduced"]=0.001,
			});

			timer.Create(8, function()
				if (not IsValid(player)) then return; end

				playerdata.scout_drinking_soda = false;

				player:SetForcedTauntCam(0);
				playerdata.scout_should_spawn_tempent = false;
				pcall(timer.Stop, playerdata.scout_tempent_timer);
				playerdata.scout_tempent_timer = nil;

				if (player.m_iClass == TF_CLASS_SCOUT) then
					player:SetAttributeValues({
						["voice pitch scale"]=1, ["move speed bonus"]=move_speed, ["fire rate bonus"]=1,
						["mult dmgtaken from melee"]=1, ["air dash count"]=0, ["increased jump height"]=jump_height,
						["cancel falling damage"]=0, ["dmg taken from crit reduced"]=dmgfromcrits,
					});
				end
			end, 1);
		end, 1);

		timer.Create(1.2, function()
			if (not IsValid(player)) then return; end

			playerdata.scout_should_spawn_tempent = true;
		end, 1);
	end
end

-- Parry those filthy peasants!
function PlayerParry(player, wep, viewmodel, idleseq, inspectseq, playbackrate, idletime, attacktime, parrytimemin, parrytimemax)
	if (not IsValidAliveRealPlayer(player)) then return; end
	
	local playerdata = player_list[player:GetUserId()];
	local curtime    = CurTime();

	-- We only want to parry when idle
	-- We also check next attack time for if we idle early
	if (viewmodel.m_nSequence == idleseq and curtime >= wep.m_flNextPrimaryAttack) then
		player:AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE, 1);
		player:PlaySoundToSelf("weapons/demo_sword_swing"..math.random(1,3)..".wav");
		
		-- Fake an attack animation for other players
		local penalty = wep:GetAttributeValue("damage penalty") or 1;
		wep:SetAttributeValue("damage penalty", 0);
		wep:RunScriptCode("self.PrimaryAttack()");
		timer.Create(0.3, function() wep:SetAttributeValue("damage penalty", penalty); end, 1);
		
		wep.m_flTimeWeaponIdle     = curtime + idletime;
		wep.m_flNextPrimaryAttack  = curtime + attacktime;
		viewmodel.m_flPlaybackRate = playbackrate;
		viewmodel.m_flCycle        = 0.0;
		viewmodel.m_nSequence      = inspectseq;
		
		timer.Create(parrytimemin, function()
			if (not playerdata) then return; end
			
			playerdata.demo_parry_count = 0;
			playerdata.demo_parrying = true;
		end, 1);
		timer.Create(parrytimemax, function()
			if (not playerdata) then return; end
			
			playerdata.demo_parry_count = 0;
			playerdata.demo_parrying = false;
		end, 1);
	end
end

-- Play a sound at a generic position
function PlaySound(sound, position)
	local ent = ents.CreateWithKeys("info_target", {}, true, true);

	ent:SetAbsOrigin(position);
	ent:PlaySound(sound);
	ent:Remove();
end

-- Get key with random chance from table of format:
-- key : probability
-- or
-- key : {roll_chance=probability, charge_chances={[1]=probability}}
-- see: spell_rng_*_chances for example
table.RandomChance = function(t)
	local rand = math.random()
	local cumulativeProbability = 0

	for key, item in pairs(t) do
		if (type(item) == "table") then
			cumulativeProbability = cumulativeProbability + item.roll_chance;
		else
			cumulativeProbability = cumulativeProbability + item;
		end

		if (rand <= cumulativeProbability) then
			return key;
		end
	end
end

timer.CreateThink = function(interval, func, repeats, testfunc, ...)
	local think_timer = nil;
	local args = {...};
	think_timer = timer.Create(interval, function()
		if (not testfunc(table.unpack(args))) then
			pcall(timer.Stop, think_timer);
			return;
		end
		
		func();
	end, repeats);
	
	return think_timer;
end