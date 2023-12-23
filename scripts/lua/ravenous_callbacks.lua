-- Cleanup code
	-- general cleanup
	-- repurpose fugly functions (e.g. spellmimic func (try to implement custom spawned weapons as well / instead?))
	-- Generalize and fixup the yanderedev upgrade code
-- Add a few more custom spells
-- add some more flasks? need to see how people like medic flasks to begin with, havent tested
-- make cage model for kinky to respawn in for other maps lol
-- fix civilian regen and crit damage before testing if raf doesnt fix


-- Called when a spell projectile spawns
function OnSpellProjectileSpawned(entity)
    local player = entity.m_hOwnerEntity;
    if (not IsValidRealPlayer(player) or not player:IsWizard()) then return; end

    -- Projectiles spawned by Meteor Shower should be ignored
    if (entity.m_hLauncher == entity.m_hOwnerEntity and
        entity.m_iClassname == "tf_projectile_spellfireball") then return; end

    local userid     = player:GetUserId();
    local playerdata = player_list[userid];

    local spellbook = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
    if (not spellbook or spellbook.m_iClassname ~= "tf_weapon_spellbook") then return; end

    local spell       = spellbook.m_iSelectedSpellIndex;
    local customspell = spellbook._m_iCustomSelectedSpellIndex;

    if (playerdata.wizard_type == WIZARD_USE_MANA) then
        -- Get the mana cost of this spell
        local current_mana_cost = 0;
        if (spell >= 0 or (customspell and customspell >= 0)) then
            local cost = GetSpellData(player, spell, customspell, "mana_cost", true);
            if (cost) then current_mana_cost = cost; end
        end

        -- Not enough mana for this spell
        if (playerdata.current_mana - current_mana_cost < 0) then
            local player_origin = player:GetAbsOrigin();

            player:TakeDamage({
                Attacker         = player,
                Inflictor        = entity,
                Weapon           = player.m_hActiveWeapon,
                Damage           = 25,
                DamageType       = DMG_SHOCK,
                DamageCustom     = TF_DMG_CUSTOM_NONE,
                DamagePosition   = player_origin,
                DamageForce      = Vector(0,0,0),
                ReportedPosition = player_origin,
            });
			
            entity:Remove();
            player:PlaySoundToSelf("Halloween.spell_lightning_cast");
			player:Print(PRINT_TARGET_CENTER, "Not enough mana!");
			
            return;
        end

        -- Valid spell cast
        playerdata.current_mana = playerdata.current_mana - current_mana_cost;
    end

    -- Call customspell spawn callback if available
    if (spellbook and customspell) then
        entity:Remove();

        local spawnfunc = spell_data[customspell].SpawnFunction;
        if (spawnfunc) then
            spawnfunc(player, spellbook)
        end
    end
end

-- Called when a tf_projectile_cleaver entity spawns
function OnCleaverProjectileSpawned(entity)
	local owner = entity.m_hOwnerEntity;
	if (not IsValidRealPlayer(owner)) then return; end
	
	-- We only want to work with demo's battle hatchet, ignore scout cleavers
	local playerdata = player_list[owner:GetUserId()];
	local cleaver    = playerdata.demo_hatchet_cleaver;
	if (not IsValid(cleaver)) then return; end
	
	-- We create a prop_dynamic instead of setting the model on the projectile
	-- because the game automatically rotates the projectile on the x axis and this model's
	-- starting orientation isn't compatible with that functionality
	local prop = ents.CreateWithKeys("prop_dynamic", {
		solid = 0,
		model = "models/workshop/weapons/c_models/c_celtic_cleaver/c_demo_sultan_sword.mdl",
		DisableBoneFollowers  = true,
		disablereceiveshadows = true,
		disableshadows        = true,
	}, true, true);
	entity:SetModelOverride("models/empty.mdl");
	
	local ang = Vector(180, owner:GetEyeAngles().y - 90, -90); -- The last airbender
	
	local think_timer = nil;
	think_timer = timer.Create(0.015, function()
		-- Do we still exist?
		if (IsValid(entity)) then
			-- We bounced off the world, the cleaver can handle physics now
			if (entity.m_bTouched == 1) then
				entity:SetModelOverride("models/workshop/weapons/c_models/c_celtic_cleaver/c_demo_sultan_sword.mdl");
				goto cleanup;
				
			-- Update prop position and rotation
			-- SetParent doesn't work and SetFakeParent is laggy so doing this manually is best
			else
				prop:SetAbsOrigin(entity:GetAbsOrigin());
				prop:SetAbsAngles(ang);
				ang.z = ang.z + 7.5; -- Speeeeeeeen
				
				return;
			end
		end
		
		-- If not, cleanup timer and prop
		::cleanup::
			
		pcall(timer.Stop, think_timer);
		think_timer = nil;
		prop:Remove();
	end, 0);
end

-- Called when a player plays a vcd file
function OnScriptedSceneSpawned(entity)
	local owner = entity.m_hOwner;
	if (not IsValidRealPlayer(owner)) then return; end
	
	local playerdata = player_list[owner:GetUserId()];
	
	local vcdpath = entity.m_szInstanceFilename;
	if (not vcdpath or vcdpath == "") then return; end
	
	-- Demo's bottle taunt
	if (#vcdpath >= 33 and string.sub(vcdpath, 1, 33) == "scenes/player/demoman/low/taunt03") then
		if (playerdata.demo_scrumpy_charge < 1) then return; end
		
		-- tf_weapon_bottle only (no battle hatchet)
		local wep = owner.m_hActiveWeapon;
		if (not IsValid(wep)) then return; end
		if (wep.m_iClassname ~= "tf_weapon_bottle" or wep:GetAttributeValue("back headshot") == 1) then return; end 
		
		-- Wait a bit
		timer.Create(2.6, function()
			if (not IsValidAliveRealPlayer(owner)) then return; end
			
			playerdata.demo_scrumpy_charge = 0;
			
			local curtime = CurTime();
			
			local roll         = 0;
			local nextblackout = curtime; -- Aah me eye!
			local duration     = 20;
			local finishtime   = curtime + duration; -- Sobered up at last
			
			-- Screen fade color
			local red   = 255;
			local green = 255;
			local blue  = 255;
			local alpha = 50;
			local step  = 5;
			
			owner:AddCond(TF_COND_GRAPPLED_TO_PLAYER, duration)        -- No taunting
			owner:AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE, duration); -- Melee only
			owner:AddCond(TF_COND_CRITBOOSTED_USER_BUFF, duration)     -- Shing! sparkle sparkle
			owner:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 2);
			
			playerdata.demo_drunk_timer = timer.Create(0.015, function()
				if (not IsValidAliveRealPlayer(owner)) then goto cleanup; end
				
				curtime = CurTime();
				
				-- Why is the rum always gone
				if (curtime >= finishtime) then
					-- Reset view
					local ang = owner:GetEyeAngles();
					ang.z = 0;
					owner:SnapEyeAngles(ang);
					
					-- Sober up, Demo
					owner:PlaySoundToSelf(demo_sober_sounds[math.random(1,4)]);
					owner:RunScriptCode("ScreenFade(self, 255, 255, 255, 255, 0.5, 0.5, 1)");
					
					-- We're done thinking
					goto cleanup;
				end
				
				-- Black out occasionally. Don't trip, demo
				if (curtime >= nextblackout) then
					red = 0; green = 0; blue = 0; alpha = 255;
					nextblackout = curtime + 10.5;
					
				else
					if (math.random(0, 1) == 1) then red = red + step;
					else red = red - step; end
					if (math.random(0, 1) == 1) then green = green + step;
					else green = green - step; end
					if (math.random(0, 1) == 1) then blue = blue + step;
					else blue = blue - step; end
					
					alpha = 50;
				end
				
				-- Block statement here to allow return; to be skipped by goto
				do
					local fade = math.randomfloat(0.5, 1);
					owner:RunScriptCode(string.format("ScreenFade(self, %d, %d, %d, %d, %f, %f, 1)", red, green, blue, alpha, fade, fade));
					return;
				end
				
				::cleanup::

				pcall(timer.Stop, playerdata.demo_drunk_timer);
				playerdata.demo_drunk_timer = nil;
			end, 0);
		end, 1);
		
	-- Heavy munchin on a snack
	elseif (vcdpath == "scenes/player/heavy/low/taunt04.vcd") then
		-- Wait a bit
		timer.Create(0.5, function()
			if (not IsValidAliveRealPlayer(owner)) then return; end
			
			local wep = owner:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
			if (not IsValid(wep) or wep.m_iClassname ~= "tf_weapon_lunchbox") then return; end
			local index = wep.m_iItemDefinitionIndex;
			
			-- Hack to get sandvich to be consumed
			if ((index == 42 or index == 1002 or index == 863 or index == 1190) and owner.m_iHealth > 1) then
				owner:TakeDamageSimple(1);
			end
			
			-- Sandvich
			if (index == 42 or index == 1002) then
				owner:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 6);
				owner.m_iHealth = owner.m_iMaxHealth;
				owner:PlaySoundToSelf("player/invulnerable_on.wav");
				
			-- Chocolate
			elseif (index == 159 or index == 433) then
				owner:AddCond(TF_COND_DEFENSEBUFF, 6);
				owner:PlaySoundToSelf("weapons/buffed_on.wav");
			
			-- Banana
			elseif (index == 1190) then
				owner:AddCond(TF_COND_SPEED_BOOST, 8);
				owner:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 2); -- Shorter taunt time means less health gained
				owner:PlaySoundToSelf("Halloween.spell_overheal");
			
			-- Robo-Sandvich
			elseif (index == 863) then
				owner:BotsIgnoreFor(6);
				owner:PlaySoundToSelf("misc/halloween/spell_pickup_rare.wav");
				owner:Print(PRINT_TARGET_CENTER, "The enemy bots won't target you!");
			end
		end, 1);
	end
end

-- Called when an entity touches a healthkit
function OnHealthkitTouch(entity, other, hitPos, hitNormal)
	-- Only allow players
	if (not IsValidPlayer(other)) then return; end
	
	-- Only allow healthkits with an owner (lunchbox pickups)
	local owner = entity.m_hOwnerEntity;
	if (not IsValidRealPlayer(owner)) then return; end
	
	-- Don't do special effects from our own pickup
	if (other == owner) then return; end
	
	-- Only proceed if the owner has a lunchbox item secondary
	local secondary = owner:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
	if (not IsValid(secondary) or secondary.m_iClassname ~= "tf_weapon_lunchbox") then return; end
	local index = secondary.m_iItemDefinitionIndex;
		
	-- For enemies
	-- Robo-Sandvich
	if (index == 863 and other.m_iTeamNum ~= owner.m_iTeamNum) then
		-- Don't affect bosses until they're relatively low health
		if (other.m_bIsMiniBoss == 1 and other.m_iHealth > 9000) then return; end
	
		-- Bye-bye sandvich
		entity:Remove()
		
		-- Giants
		if (other.m_bIsMiniBoss == 1) then
			-- We wait a frame for the healthkit to die, we don't want giants healed by it
			timer.Create(0.015, function()
				if (not IsValidAlivePlayer(other) or other.m_iTeamNum == TEAM_SPECTATOR) then return; end
				
				other:AddCond(TF_COND_REPROGRAMMED, 7);
				other:AddCond(TF_COND_CRITBOOSTED_USER_BUFF, 7);
				other:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 5);
			end, 1);
		-- Commons
		else
			-- Still on the same frame, the small bot will be healed by the healthkit right as it turns red
			other:AddCond(TF_COND_REPROGRAMMED, 11); -- 10+1 so timer below can run
			other:AddCond(TF_COND_CRITBOOSTED_USER_BUFF, 10);
			other:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 8);
			other:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 4);
			
			other:BotCommand("switch_action Mobber");
			
			-- Time to die
			timer.Create(10, function()
				if (not IsValidAlivePlayer(other) or other.m_iTeamNum == TEAM_SPECTATOR) then return; end
				
				if (other:InCond(TF_COND_REPROGRAMMED)) then
					other:Suicide();
				end
			end, 1);
		end
	
	-- For friends
	elseif (other.m_iTeamNum == owner.m_iTeamNum) then
		-- Sandvich
		if (index == 42 or index == 1002) then
			other:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 8);
			other:PlaySoundToSelf("player/invulnerable_on.wav");
			
		-- Steak
		elseif (index == 311) then
			other:AddCond(TF_COND_SPEED_BOOST, 8);
			other:AddCond(TF_COND_CRITBOOSTED_USER_BUFF, 4);
		
		-- Chocolate
		elseif (index == 159 or index == 433) then
			other:AddCond(TF_COND_DEFENSEBUFF, 8);
			other:PlaySoundToSelf("weapons/buffed_on.wav");
		
		-- Banana
		elseif (index == 1190) then
			other:AddCond(TF_COND_SPEED_BOOST, 4);
			other:PlaySoundToSelf("Halloween.spell_overheal");
			if (other.m_iHealth < other.m_iMaxHealth) then
				other.m_iHealth = other.m_iMaxHealth;
			end
		
		-- Robo-Sandvich
		elseif (index == 863) then
			other:BotsIgnoreFor(8);
			other:PlaySoundToSelf("misc/halloween/spell_pickup_rare.wav");
			other:Print(PRINT_TARGET_CENTER, "The enemy bots won't target you!");
		end
		
		-- Bye-bye sandvich
		entity:Remove();
	end
end

-- Called when a healthkit spawns
function OnHealthkitSpawned(entity)
	local owner = entity.m_hOwnerEntity;
	if (not IsValidRealPlayer(owner)) then return; end

	entity:AddCallback(ON_TOUCH, OnHealthkitTouch);
end

function OnJarateProjectileRemoved(entity)
	local owner = entity._m_hOwnerEntity;
	if (not IsValidPlayer(owner)) then return; end
	
	-- Only projectiles from Flask weapon
	local secondary = owner:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
	if (not IsValid(secondary) or secondary:GetAttributeValue("store sort override DEPRECATED") ~= 1) then return; end
	
	local entities = ents.FindInSphere(entity:GetAbsOrigin(), 200);
	for index, ent in pairs(entities) do
		if (IsValidAlivePlayer(ent)) then
			local flasktype = entity._m_nFlaskType;
			
			if (ent.m_iTeamNum ~= owner.m_iTeamNum) then
				if (flasktype == FLASK_NONE or flasktype == FLASK_BLEED) then
					ent:TakeDamageSimple(60, owner);
					
					timer.CreateThink(0.5, function()
						ent:TakeDamageSimple(5, owner, TF_DMG_CUSTOM_BLEEDING);
					end, 8, IsValidAlivePlayer, ent);
					
				elseif (flasktype == FLASK_HEAL_DEBUFF) then
					local attr = ent:GetAttributeValue("healing received penalty") or 1;
					ent:SetAttributeValue("healing received penalty", 0.001);
					
					timer.Create(8, function()
						if (not IsValidPlayer(ent)) then return; end
						ent:SetAttributeValue("healing received penalty", attr);
					end, 1);
				end

			else
				if (flasktype == FLASK_LONGHEAL) then
					ent:PlaySoundToSelf("weapons/medigun_heal.wav");
					timer.CreateThink(0.5, function()
						ent:AddHealth(15, false);
					end, 40, IsValidAlivePlayer, ent);
					
				elseif (flasktype == FLASK_QUICKHEAL) then
					ent:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 4);
					ent:PlaySoundToSelf("Halloween.spell_overheal");
					
				elseif (flasktype == FLASK_UBER) then
					ent:AddCond(TF_COND_INVULNERABLE_USER_BUFF, 2);
					ent:PlaySoundToSelf("player/invulnerable_on.wav");
				end
			end
		end
	end
end

function OnPickupStartTouch(entity, other, hitPos, hitNormal)
	if (IsValidAliveRealPlayer(other)) then
		if (entity._ignoreclass or entity._class == other.m_iClass) then
			other:Print(PRINT_TARGET_CENTER, "Press <Reload> to pick up!");
			other._touchingpickup = entity;
		end
	end
end

function OnPickupEndTouch(entity, other, hitPos, hitNormal)
	if (IsValidAliveRealPlayer(other)) then
		if (entity._ignoreclass or entity._class == other.m_iClass) then
			other:Print(PRINT_TARGET_CENTER, "");
			other._touchingpickup = nil;
		end
	end
end

-- Called when a spell projectile is created
function OnSpellProjectileCreated(entity, classname)
    entity:AddCallback(ON_SPAWN, OnSpellProjectileSpawned);
end

-- Called when a tf_projectile_cleaver entity is created
function OnCleaverProjectileCreated(entity, classname)
	entity:AddCallback(ON_SPAWN, OnCleaverProjectileSpawned);
end

function OnJarateProjectileCreated(entity, classname);
	-- We do this because m_hOwnerEntity is cleared (nil) when we try to access it in ON_REMOVE
	-- Also to prevent medics from switching their flask type after they throw it
	entity:AddCallback(ON_SPAWN, function(entity)
		local owner = entity.m_hOwnerEntity;
		if (not IsValidRealPlayer(owner)) then return; end
		
		local playerdata = player_list[owner:GetUserId()];
		
		entity._m_hOwnerEntity = owner;
		entity._m_nFlaskType   = playerdata.medic_current_flask;
	end);
	
	entity:AddCallback(ON_REMOVE, OnJarateProjectileRemoved);
end

-- Called when a tf_ragdoll entity is created
function OnRagdollCreated(entity, classname)
    -- Send those zombies to the shadow realm
    timer.Create(0.1, function()
        if (not IsValid(entity)) then return; end

        local player = entity.m_hPlayer;
        if (player.m_iTeamNum == TEAM_BLUE) then
            pcall(entity.Remove, entity);
        end
    end, 1)
end

-- Called when an instanced_scripted_scene entity is created
function OnScriptedSceneCreated(entity, classname)
	entity:AddCallback(ON_SPAWN, OnScriptedSceneSpawned);
end

-- Called when a healthkit is created
function OnHealthkitCreated(entity, classname)
	entity:AddCallback(ON_SPAWN, OnHealthkitSpawned);
end

function OnPickupCreated(entity, classname)
	entity:AddCallback(ON_START_TOUCH, OnPickupStartTouch);
	entity:AddCallback(ON_END_TOUCH, OnPickupEndTouch);
end

local badplayers = {};

-- Called every game tick (15ms)
function OnGameTick()
    local kinky_player = false;

    -- Fall back just in case OnPlayerDisconnected doesn't fire for some reason
    if (table.Count(badplayers) > 0) then
        for index, userid in pairs(badplayers) do
            player_list[userid] = nil;
        end
        badplayers = {};
    end
	
	-- RNG Spells seconds timer
	if ((debug or midwave) and TickCount() % tickrate == 0) then
		common_timer_value = common_timer_value - 1
		rare_timer_value   = rare_timer_value   - 1

		-- We check rare first because it should take priority if their timers both land on the same second
		if (rare_timer_value == 0) then
			GiveWizardsSpell(SPELL_TYPE_RARE);
			rare_timer_value = rare_spell_time;

			-- Reset the common timer if we skipped over it executing
			if (common_timer_value == 0) then common_timer_value = common_spell_time; end

		elseif (common_timer_value == 0) then
			GiveWizardsSpell(SPELL_TYPE_COMMON);
			common_timer_value = common_spell_time;
		end
	end

    -- Loop through our human players
    for userid, playerdata in pairs(player_list) do
        local player = ents.GetPlayerByUserId(userid);

        -- Degenerate player handle, store and continue
        if (not IsValidRealPlayer(player)) then
            table.insert(badplayers, userid);
            goto continue;
        end

        -- Spectators don't need to be handled
        if (player.m_iTeamNum == TEAM_SPECTATOR) then goto continue; end

        if (player.m_iClass == TF_CLASS_SCOUT) then

            -- Player is in bonk or crit a cola effects when they shouldn't be
            -- Can result from multiple things, frame perfect drink soda on land while still considered midair is one,
            -- Another is resupplying after drinking soda and drinking again before the effects are done
            if (player:IsAlive() and ((player:InCond(TF_COND_PHASE) or player:InCond(TF_COND_ENERGY_BUFF)) or
                (player:GetAttributeValue("cancel falling damage") == 1)) and
                not playerdata.scout_drinking_soda) then

                player:RemoveCond(TF_COND_PHASE);

                -- Crit-a-Cola instantly applies it's condition before scout_drinking_soda can be set
                -- which causes the code to run twice, this delay prevents that
                timer.Create(0.1, function()
                    if (not IsValidRealPlayer(player)) then return; end

                    if (not playerdata.scout_drinking_soda) then
                        local wep = player.m_hActiveWeapon;
                        if (IsValid(wep)) then
                            PlayerDrinkSoda(player, wep.m_iItemDefinitionIndex);
                        end
                    end
                end, 1)
            end

            -- Crit-a-Cola movement sparks
            if (playerdata.scout_should_spawn_tempent) then
                if (player:IsWalking()) then
                    if (not playerdata.scout_tempent_timer) then
                        local soundtable = {};
                        for i=1,4 do table.insert(soundtable, "ambient/energy/spark"..i..".wav"); end

                        playerdata.scout_tempent_timer = CreateTETimer(player, "Sparks", {
                            m_nMagnitude   = 2,
                            m_nTrailLength = 1,
                            m_vecDir       = Vector(0, 0, 0),
                        }, soundtable, 1);
                    end
                else
                    pcall(timer.Stop, playerdata.scout_tempent_timer);
                    playerdata.scout_tempent_timer = nil;
                end
            end


        elseif (player.m_iClass == TF_CLASS_SOLDIER) then
            local wep = player.m_hActiveWeapon;
            if (IsValid(wep) and wep.m_iItemDefinitionIndex == 416) then -- Market Gardener
                -- HUD display
                if (TickCount() % (tickrate * 3) == 0) then -- Just a label to display, so less updates for perf
                    DisplaySoldierHud(player);
                end
            end


        elseif (player.m_iClass == TF_CLASS_PYRO) then
            local charge     = playerdata.pyro_aoeblast_charge;
            local chargetime = playerdata.pyro_aoeblast_chargetime;

            -- Charge regen
            if (charge < 1) then
                if (TickCount() % tickrate == 0) then
                    charge = charge + 1 / (chargetime);
                    if (charge > 1) then charge = 1; end

                    playerdata.pyro_aoeblast_charge = charge;
                end
            end

            -- HUD display
            if (TickCount() % tickrate == 0) then
                local label = nil;
                if (charge == 1) then label = "READY";
                else label = math.round(charge * 100, 2).."%"; end

                local damagebonus_label = playerdata.pyro_aoeblast_damagebonus;
                if (damagebonus_label == 1) then damagebonus_label = "0%";
                else damagebonus_label = math.round((damagebonus_label - 1) * 100).."%"; end

                DisplayPyroHud(player, label, chargetime, damagebonus_label);
            end
			
			
        elseif (player.m_iClass == TF_CLASS_DEMOMAN) then
			local wep = player:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE);
			if (not IsValid(wep)) then goto continue; end
			
			if (wep.m_iClassname == "tf_weapon_bottle" and wep:GetAttributeValue("back headshot") ~= 1) then
				local charge     = playerdata.demo_scrumpy_charge;
				local chargetime = playerdata.demo_scrumpy_chargetime;
				
				-- Charge regen while not drunk
				if (not playerdata.demo_drunk_timer and charge < 1) then
					if (TickCount() % tickrate == 0) then
						charge = charge + 1 / (chargetime);
						if (charge > 1) then charge = 1; end

						playerdata.demo_scrumpy_charge = charge;
					end
				end
			
				-- HUD Display
				if (TickCount() % tickrate == 0) then
					local label = nil;
					if (charge == 1) then label = "READY";
					else label = math.round(charge * 100, 2).."%"; end
					DisplayDemoScrumpyHud(player, label, chargetime);
				end
			else
				-- HUD Display
				if (TickCount() % (tickrate * 3) == 0) then -- Just a label to display, so less updates for perf
					DisplayDemoHud(player, wep);
				end
			end
			

        elseif (player.m_iClass == TF_CLASS_ENGINEER) then
            if (not player:IsWizard()) then goto continue; end

            -- Mana regen
            if (TickCount() % tickrate == 0) then
                if (playerdata.current_mana + playerdata.mana_regen_rate <= playerdata.max_mana) then
                    playerdata.current_mana = playerdata.current_mana + playerdata.mana_regen_rate;
                else
                    playerdata.current_mana = playerdata.max_mana;
                end
            end

            local spellbook = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
            if (not spellbook or spellbook.m_iClassname ~= "tf_weapon_spellbook") then goto continue; end

            local spell       = spellbook.m_iSelectedSpellIndex;
            local customspell = spellbook._m_iCustomSelectedSpellIndex;
            local lastspell   = customspell or spell or SPELL_NONE;

            -- Re-roll our last spell when we run out
            if ((debug or midwave) and not playerdata.spell_reroll_timer and 
				playerdata.wizard_type == WIZARD_USE_MANA and
				lastspell >= 0 and spellbook.m_iSpellCharges == 0) then

                playerdata.spell_reroll_timer = timer.Create(0.5, function()
                    if (not IsValid(spellbook) or not IsValidRealPlayer(player)) then
						if (playerdata and playerdata.spell_roll_timer) then
							playerdata.spell_reroll_timer = nil;
						end
						
						return;
					end

					-- Only reroll the spell if we aren't already choosing by the time this runs
					if (spellbook.m_iSelectedSpellIndex ~= SPELL_CHOOSING) then
						SelectSpell(spellbook, lastspell,
									GetSpellData(player, nil, lastspell, "charges", true),
									GetSpellData(player, nil, lastspell, "roll_time", false), false, true);
					end
								
					playerdata.spell_reroll_timer = nil;
                end, 1);
            end

            -- Get our spell's mana cost
            local current_mana_cost = GetSpellData(player, spell, customspell, "mana_cost", true);
            if (not current_mana_cost) then
                current_mana_cost = 0;
            end

            -- HUD display
            if (TickCount() % tickrate == 0) then
                if (playerdata.wizard_type == WIZARD_USE_MANA) then
                    DisplayManaWizardHud(player, spellbook, playerdata, current_mana_cost);
                elseif (playerdata.wizard_type == WIZARD_USE_ROLLS) then
                    DisplayRollsWizardHud(player, spellbook);
                end
            end


		elseif (player.m_iClass == TF_CLASS_MEDIC) then
			local wep = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
			if (IsValid(wep) and wep:GetAttributeValue("store sort override DEPRECATED") == 1) then
				-- HUD Display
				if (TickCount() % tickrate == 0) then
					DisplayMedicHud(player, flask_name_map[playerdata.medic_current_flask]);
				end
			end


        elseif (player.m_iClass == TF_CLASS_SPY and player:IsAlive()) then
            -- Regen health while cloaked (30/s)
            if (player:InCond(TF_COND_STEALTHED) and
                not player:InCond(TF_COND_FEIGN_DEATH)) then

                if (TickCount() % 11 == 0) then
                    player:AddHealth(5, false);
                end
            end
			
			local wep = player.m_hActiveWeapon;
			if (not IsValid(wep)) then goto continue; end
			
			local watch = player:GetPlayerItemBySlot(LOADOUT_POSITION_PDA2);
			
			-- Flintlock Pistol reloading with Dead Ringer equipped
			if (IsValid(watch) and watch.m_iItemDefinitionIndex == 59) then
				if (wep:GetAttributeValue("rj air bombardment") == 1 and player.m_hViewModel[1].m_nSequence == 5) then
					player.m_flStealthNextChangeTime = CurTime() + 10; -- Prevents using dr while reloading which speeds up the reload anim
					player._m_bReloadingFlintlock    = 1;
				elseif (player._m_bReloadingFlintlock == 1 and player.m_hViewModel[1].m_nSequence ~= 5) then
					player.m_flStealthNextChangeTime = 0;
					player._m_bReloadingFlintlock    = 0;
				end
			end

        elseif (player.m_iClass == TF_CLASS_CIVILIAN) then
            kinky_player = true; -- Used to determine if we need to disable dungeon props

            -- Calculate his damage bonus based on his currency
            local kinky_dmgbonus = nil;
            local currency = player.m_nCurrency;
            if (currency and currency >= 0) then
                if (currency >= kinky_maxdmgatcurrency) then
                    kinky_dmgbonus = kinky_maxdmg;
                elseif (currency >= 0) then
                    kinky_dmgbonus = kinky_mindmg + (currency * ((kinky_maxdmg - kinky_mindmg) / kinky_maxdmgatcurrency));
                end
            else
                kinky_dmgbonus = kinky_mindmg;
            end

            -- Apply the damage bonus
            local wep = player.m_hActiveWeapon;
            if (wep) then
                wep:SetAttributeValue("damage bonus", kinky_dmgbonus);
            end

            -- If we're holding mouse2 when our ability finishes recharging, start charging superdash
            if (playerdata.holding_mouse2 and playerdata.kinky_superdash_recharge == 1 and not player.m_hItem) then
                playerdata.kinky_charging_superdash = true;
            end

            -- Midair
            if (player:IsMidair()) then
                playerdata.kinky_can_goombastop = player.m_vecAbsVelocity.z < -500;

                -- Weighdown
                if (playerdata.crouching and player["m_angEyeAngles[0]"] >= 60) then
                    if (not playerdata.kinky_weighdown_timer) then
                        playerdata.kinky_weighdown_timer = timer.Create(0.015, function()
                            if (not IsValidRealPlayer(player)) then
                                if (playerdata and playerdata.kinky_weighdown_timer) then
                                    pcall(timer.Stop, playerdata.kinky_weighdown_timer);
                                    playerdata.kinky_weighdown_timer = nil;
                                end
                            end

                            local velocity = player.m_vecAbsVelocity;

                            -- If going up, stop our velocity relatively quickly
                            if velocity.z > 0 then
                                velocity.z = velocity.z * 0.5;
                            -- Otherwise, set our velocity based on inverse exponential
                            -- Lower  velocity : higher mod
                            -- Higher velocity : lower  mod
                            else
                                local mod = 1 + math.abs(1 / velocity.z * 50);
                                velocity.z = velocity.z * mod;
                            end

                            player.m_vecAbsVelocity = velocity;
                        end, 0)
                    end
                end

            -- Not midair
            else
                -- Stop weighdown think
                if (playerdata.kinky_weighdown_timer) then
                    pcall(timer.Stop, playerdata.kinky_weighdown_timer);
                    playerdata.kinky_weighdown_timer = nil;
                end

                -- Goomba Stomp
                if (playerdata.kinky_can_goombastop) then
                    local victim = player.m_hGroundEntity;
                    if (IsValidPlayer(victim) and player.m_iTeamNum ~= victim.m_iTeamNum) then

                        local pos = player:GetAbsOrigin();

                        -- One shot small bots, otherwise deal 300 damage
                        local dmg = 300;
                        if (victim.m_bIsMiniBoss ~= 1) then
                            dmg = victim.m_iHealth * 6;
                        end

                        if (victim:IsInvuln()) then
                            victim:AddHealth(-dmg)
                        else
                            victim:TakeDamage({
                                Attacker         = player,
                                Inflictor        = nil,
                                Weapon           = wep,
                                Damage           = dmg,
                                DamageType       = DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE,
                                DamageCustom     = TF_DMG_CUSTOM_BOOTS_STOMP,
                                DamagePosition   = pos,
                                DamageForce      = Vector(0,0,0),
                                ReportedPosition = pos,
                            });
                        end

                        victim:PlaySound("Weapon_Mantreads.Impact");
                        victim:PlaySound("Player.FallDamageDealt");
                        util.ParticleEffect("stomp_text", pos);
                    end
                end
				
                playerdata.kinky_can_goombastop = false;
            end

            -- Kinky charging Super Dash
            if (playerdata.kinky_charging_superdash) then
                local charge     = playerdata.kinky_superdash_charge;
                local chargetime = playerdata.kinky_superdash_chargetime;
				
				if (not player.m_hItem) then
					-- Increase dash charge
					if (charge < 1) then
						charge = charge + 1 / (tickrate * chargetime);
						if (charge > 1) then charge = 1; end

						playerdata.kinky_superdash_charge = charge;
					end

					-- Display charge
					local label = nil;
					if (charge == 1) then label = "READY";
					else label = math.round(charge * 100).."%"; end

					player:Print(PRINT_TARGET_CENTER, label);
					
				-- We picked up an item
				else
					playerdata.kinky_charging_superdash = false;
					playerdata.kinky_superdash_charge   = 0;
					player:Print(PRINT_TARGET_CENTER, ""); -- Clear display
				end
            end


            -- HUD display
            if (TickCount() % tickrate == 0) then
                local charge          = playerdata.kinky_rage_charge;
                local chargetime      = playerdata.kinky_rage_chargetime
                local supercharge     = playerdata.kinky_superdash_recharge
                local superchargetime = playerdata.kinky_superdash_rechargetime;

                local label             = "0%";
                local supercharge_label = "0%";

                -- Increase rage charge
                if (debug or midwave) then
                    if (charge < 1) then
                        charge = math.round(charge + 1 / chargetime, 2);
                        if (charge > 1) then charge = 1; end

                        playerdata.kinky_rage_charge = charge;
                    end

                    if (charge == 1) then label = "READY";
                    else label = math.round(charge * 100, 2).."%"; end
                end

                -- Increase super dash recharge
                if (supercharge < 1) then
                    supercharge = math.round(supercharge + 1 / superchargetime, 2);
                    if (supercharge > 1) then supercharge = 1; end

                    playerdata.kinky_superdash_recharge = supercharge;
                end

                if (supercharge == 1) then supercharge_label = "READY";
                else supercharge_label = math.round(supercharge * 100, 2).."%"; end

                DisplayCivilianHud(player, label, chargetime, supercharge_label, superchargetime);
            end
        end

        ::continue::
    end

    -- Someone is playing Captain Kinky, disable his props in the dungeon
    if (kinky_player) then
        if (not kinky_props_disabled) then
            kinky_props_disabled = true;

            for index, ent in pairs(dungeon_entities) do
                if (IsValid(ent)) then
                    ent:Disable();
                end
            end
        end

    -- Otherwise clean up the respawn display entities and enable the props again
    else
        if (IsValid(kinky_respawn_text) and IsValid(kinky_respawn_text2)) then
            kinky_respawn_text:AddOutput("message ");
            kinky_respawn_text2:AddOutput("message ");
        end

        if (kinky_props_disabled) then
            kinky_props_disabled = false;

            for index, ent in pairs(dungeon_entities) do
                if (IsValid(ent)) then
                    ent:Enable();
                end
            end
        end
    end
end

-- Called on Civilian melee attack
function OnKinkyMeleeAttackPre(entity)
    local player = entity.m_hOwnerEntity;
    if (not IsValidRealPlayer(player)) then return; end

    -- Prevent stopping charge if we swing before or right as we begin charging
    if (player_list[player:GetUserId()].kinky_charge_time > 0.1) then
        KinkyStopCharging(player);
    end
end
local num1 = 0.2;
local num2 = 102;
-- Called on player key press
function OnPlayerKey(player, key)
    if (not IsValidAliveRealPlayer(player)) then return end;

    local userid     = player:GetUserId();
    local playerdata = player_list[userid];
    local wep        = player.m_hActiveWeapon;

    -- Mouse1
    if (key == IN_ATTACK) then
        if (player.m_iClass == TF_CLASS_SCOUT) then
            -- We use m_flNextSecondaryAttack here because it isn't set after the weapon is used, but is identical to m_flNextPrimaryAttack
            -- We can't use m_flNextPrimaryAttack because it's already been set to the next attack time by the time this logic runs
            -- We also can't use ON_FIRE_WEAPON_* because it doesn't consider scout drinking "firing the weapon"
            if (wep and CurTime() >= wep.m_flNextSecondaryAttack) then
                PlayerDrinkSoda(player, wep.m_iItemDefinitionIndex);
            end
        end

    -- Mouse2
    elseif (key == IN_ATTACK2) then
        playerdata.holding_mouse2 = true;

		-- Begone demons!
        if (debug) then
            print("DEBUG\n");
        end

        if (player:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE) == wep) then
            if (player.m_iClass == TF_CLASS_SOLDIER) then
                if (IsValid(wep) and wep.m_iItemDefinitionIndex == 416 and -- Market Gardener
                    not playerdata.soldier_airborne_timer) then

                    SpellSuperjumpSpawn(player);
                    player:AddCond(TF_COND_CRITBOOSTED_USER_BUFF);

                    local time = nil;
                    time = CurTime();
                    playerdata.soldier_airborne_timer = timer.Create(0.015, function()
                        if (not IsValidAliveRealPlayer(player)) then
                            if (playerdata and playerdata.soldier_airborne_timer) then
                                pcall(timer.Stop, playerdata.soldier_airborne_timer);
                                playerdata.soldier_airborne_timer = nil;
								
                                return;
                            end
                        end

						-- Bwaaaak!
                        if (time and CurTime() >= time + 1) then
							if (math.random(3) == 1) then player:PlaySoundToSelf("ambient/medieval_falcon.wav"); end
                            time = nil;
                        end

                        if (not player:IsMidair()) then
                            player:RemoveCond(TF_COND_CRITBOOSTED_USER_BUFF);

                            pcall(timer.Stop, playerdata.soldier_airborne_timer);
                            playerdata.soldier_airborne_timer = nil;
                        end
                    end, 0);
                end
				
			elseif (player.m_iClass == TF_CLASS_DEMOMAN) then
				if (not IsValid(wep)) then return; end
			
				local viewmodel = player.m_hViewModel[1] or player.m_hViewModel[2];
				if (not IsValid(viewmodel)) then return; end
				
				-- No parrying with a shield
				local secondary = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
				if (IsValid(secondary) and secondary.m_iClassname == "tf_wearable_demoshield") then return; end
				
				-- Persian Persuader
				if (wep.m_iItemDefinitionIndex == 404) then
					PlayerParry(player, wep, viewmodel, 8, 48, 1.5, 0.7, 1, 0.25, 0.75);
				
				-- Eyelander, Skullcutter, Claidheamohmor, Katana
				elseif (wep.m_iClassname == "tf_weapon_sword" or wep.m_iClassname == "tf_weapon_katana") then
					PlayerParry(player, wep, viewmodel, 13, 53, 5, 1, 1, 0.25, 0.75);
				end

            elseif (player.m_iClass == TF_CLASS_CIVILIAN) then
				if (player.m_hItem) then
					player:Print(PRINT_TARGET_CENTER, "You can't use this ability while carrying items!");
                elseif (playerdata.kinky_superdash_recharge < 1) then
                    player:Print(PRINT_TARGET_CENTER, "The ability isn't fully charged yet!");
                else
                    playerdata.kinky_charging_superdash = true;
                end
            end
        end

    -- Reload
    elseif (key == IN_RELOAD) then
        if (player.m_iClass == TF_CLASS_PYRO) then
            -- Fireblast
            if (playerdata.pyro_aoeblast_charge >= 1) then
                player:PlaySound("ambient/fireball.wav");

                local burndmg = player:GetAttributeValue("weapon burn dmg increased") or 1;
                local regen   = player:GetAttributeValue("health regen") or 0;

                -- Particles
                player:PlayParentedParticle("heavy_ring_of_fire", nil, 1);
                playerdata.pyro_ember_particle = player:PlayParentedParticle( "mvm_hatch_destroy_smolderembers", nil, 8,
                    function()
                        playerdata.pyro_ember_particle = nil;
                        playerdata.pyro_aoeblast_damagebonus = 1;
                        player:SetAttributeValues({
                            ["weapon burn dmg increased"] = burndmg,
                            ["damage bonus"]              = 1,
                            ["health regen"]              = regen,
                            ["mult dmgtaken from melee"]  = 1,
                        });
                    end);

                -- Initial blast determines bonus damage
                local enemy_count = DamagePlayersInBox(player, Vector(-192, -192, -64), Vector(192, 192, 128),
                                                       function(enemy_count) return 20 + (enemy_count * 2); end,
                                                       function(ent) ent:IgnitePlayerDuration(4, player); end);

                local burndmgbonus   = enemy_count * 0.05;
                local damagebonus    = enemy_count * 0.05;
                local maxdamagebonus = 0.75;

				-- Set attributes
                if (damagebonus > maxdamagebonus) then damagebonus = maxdamagebonus; end
                player:SetAttributeValues({
                    ["weapon burn dmg increased"] = burndmg + burndmgbonus,
                    ["damage bonus"]              = 1 + damagebonus,
                    ["health regen"]              = regen + 10,
                    ["mult dmgtaken from melee"]  = 0.8,

                });
                playerdata.pyro_aoeblast_damagebonus = 1 + damagebonus;
                playerdata.pyro_aoeblast_charge = 0;

                -- Secondary blasts
                if (playerdata.pyro_aoeblast_duration > 0) then
                    playerdata.pyro_aoeblast_timer = timer.Create(0.5, function()
                        if (not IsValidAliveRealPlayer(player)) then return; end

                        player:PlayParentedParticle("heavy_ring_of_fire", nil, 1);
                        DamagePlayersInBox(player, Vector(-192, -192, -64), Vector(192, 192, 128),
                                           function(enemy_count) return 20; end,
                                           function(ent) ent:IgnitePlayerDuration(2, player); end);

                    end, playerdata.pyro_aoeblast_duration * 2);
                end
            else
                player:Print(PRINT_TARGET_CENTER, "The ability isn't fully charged yet!");
            end
			
		elseif (player.m_iClass == TF_CLASS_DEMOMAN) then
			if (not IsValid(wep)) then return; end
		
			local viewmodel = player.m_hViewModel[1] or player.m_hViewModel[2];
			if (not IsValid(viewmodel)) then return; end
			
			-- Battle Hatchet, only throw if idle
			if (wep:GetAttributeValue("back headshot") == 1 and 
				viewmodel.m_nSequence == 8 and not playerdata.demo_hatchet_cleaver) then
				
				player:AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
				
				local t = CurTime() + 999;
				player:PlayVMSequence(11, 1, t, t);
				
				timer.Create(0.1, function()
					local cleaver = Entity("tf_weapon_cleaver", false, false);
					
					-- Just in case
					if (not IsValid(cleaver)) then
						player:RemoveCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
						
						t = CurTime();
						player:PlayVMSequence(8, 1, t, t);
						
						return
					end
					
					player.m_bDrawViewmodel = 0; -- Your hatchet is gone noooooo!
					
					playerdata.demo_hatchet_cleaver = cleaver;
				
					cleaver.m_iItemDefinitionIndex = 812;
					cleaver.m_bInitialized         = true;
					cleaver.m_hOwner               = player;
					
					cleaver:DispatchSpawn();
					cleaver:Activate();
					
					cleaver:SetAttributeValue("damage bonus", 3);
					cleaver:RunScriptCode("self.PrimaryAttack()");
					
					-- Recharge
					playerdata.demo_hatchet_cleaver_timer = timer.Create(playerdata.demo_hatchet_chargetime, function()
						if (cleaver) then cleaver:Remove(); end
						if (not IsValid(player) or not IsValid(wep) or not IsValid(viewmodel)) then return; end
						
						playerdata.demo_hatchet_cleaver   = nil;
						player.m_iAmmo[TF_AMMO_GRENADES2] = 1; -- Cleaver ammo
						
						player:RemoveCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
						player:PlaySoundToSelf("player/recharged.wav");
						player.m_bDrawViewmodel = 1;
						
						t = CurTime()
						player:PlayVMSequence(8, 1, t, t);					
					end, 1);
				end, 1);
			end

        elseif (player.m_iClass == TF_CLASS_ENGINEER) then
            if (not player:IsWizard() or playerdata.wizard_type ~= WIZARD_USE_MANA) then return; end

            if (not debug and player:CountUnlockedSpells() == 0) then
                player:Print(PRINT_TARGET_CENTER, "You haven't bought any spells from the Upgrades Station yet!");
                return;
            end

            -- Display spell menu
            if (debug) then
                player:DisplayMenu(debug_spell_menu);
                playerdata.displaying_menu = debug_spell_menu;
            else
                local spellmenu = CreateSpellMenuForPlayer(player);
                player:DisplayMenu(spellmenu);
                playerdata.displaying_menu = spellmenu;
            end
			
		elseif (player.m_iClass == TF_CLASS_MEDIC) then
			local wep = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
			if (not IsValid(wep) or wep:GetAttributeValue("store sort override DEPRECATED") ~= 1) then return; end
			
			if (#playerdata.medic_flask_data == 0) then
                player:Print(PRINT_TARGET_CENTER, "You haven't bought any custom flasks from the Upgrades Station yet!");
                return;
            end
			
			local flaskmenu = CreateFlaskMenuForPlayer(player);
			player:DisplayMenu(flaskmenu);
			playerdata.displaying_menu = flaskmenu;

        elseif (player.m_iClass == TF_CLASS_CIVILIAN) then
            if (not debug and not midwave) then
                player:Print(PRINT_TARGET_CENTER, "You can only use this ability once the wave starts!");
                return;
            end

            -- Rage
            if (playerdata.kinky_rage_charge >= 1) then
                playerdata.kinky_rage_charge = 0;

                player:PlayKinkyVO("kinkyrage", ".wav", 1, 2, 4);

                local player_origin = player:GetAbsOrigin();
                local entities = ents.FindInSphere(player_origin, 360);

                -- Stun bots in radius
                for index, ent in pairs(entities) do
                    if (IsValidPlayer(ent) and ent:IsAlive() and
                        ent.m_iTeamNum ~= player.m_iTeamNum and ent.m_bIsMiniBoss ~= 1) then
                        ent:StunPlayer(8, 0.25, TF_STUNFLAGS_GHOSTSCARE, player)
                    end
                end

                -- Static damage bonus for the duration of the stun
                player:SetAttributeValue("damage bonus", 1.75);

                local player_regen = player:GetAttributeValue("health regen") or 0;
                player:SetAttributeValue("health regen", 40);

				-- Reset
                timer.Create(8, function()
                    if (not IsValidPlayer(player) or player.m_iClass ~= TF_CLASS_CIVILIAN) then return; end

                    player:SetAttributeValue("damage bonus", 1);
                    player:SetAttributeValue("health regen", player_regen);
                end, 1);
            else
                player:Print(PRINT_TARGET_CENTER, "The ability isn't fully charged yet!");
            end
        end

	-- Crouch
    elseif (key == IN_DUCK) then -- Duck!
        playerdata.crouching = true;
    end
end

-- Called on player key release
function OnPlayerKeyRelease(player, key)
    local userid     = player:GetUserId();
    local playerdata = player_list[userid];
	
	-- Reload
	if (key == IN_RELOAD and IsValid(player._touchingpickup)) then
		local entity = player._touchingpickup;
		
		player:GiveLoadout(entity._cosmetics, entity._weapons, entity._class, entity._ignoreclass);
		playerdata.hp_itemname      = entity._itemname;
		playerdata.hp_cosmetics     = entity._cosmetics;
		playerdata.hp_weapons       = entity._weapons;
		playerdata.hp_ignoreclass   = entity._ignoreclass;
		playerdata.hp_class         = entity._class;
		
		player:PlaySoundToSelf("player/recharged.wav");
		player:Print(PRINT_TARGET_CENTER, "");
		entity:Remove()

    -- Mouse2
    elseif (key == IN_ATTACK2) then
        playerdata.holding_mouse2 = false;

        if (player.m_iClass == TF_CLASS_CIVILIAN) then
            playerdata.kinky_charging_superdash = false;
            player:Print(PRINT_TARGET_CENTER, ""); -- Instantly clear charge display from screen

            if (not player:IsAlive()) then goto cleanup; end

			-- Super dash is ready
            if (playerdata.kinky_superdash_charge == 1) then
                local eyeangles = player:GetEyeAngles();
                if (not eyeangles) then goto cleanup; end

                -- Looking straight.. Masturba- -I mean Charge!!
                if (eyeangles.x > -30) then
                    if (player.movetype == MOVETYPE_WALK) then
                        player:PlayKinkyVO("vo/soldier_paincrticialdeath0", ".mp3", 1, 4, 3, true);

                        player:SetAttributeValue("no_jump", 1);
                        player:SetAttributeValue("no_duck", 1);
                        player:AddCond(TF_COND_CRITBOOSTED);

                        local iter = 1;
                        local chargetimer = nil;
                        chargetimer = timer.Create(0.015, function()
                            if (not IsValidAliveRealPlayer(player)) then return; end

                            playerdata.kinky_charge_time = iter * 0.015;

                            local velocity = player.m_vecAbsVelocity;
                            local ang      = Vector(0, player["m_angEyeAngles[1]"], 0);
                            local vel      = ang:GetForward() * 1000;
                            vel.z = velocity.z; -- So we stick to the ground

                            -- What's in front of us?
                            if (iter % 5 == 0 and not util.IsLagCompensationActive()) then
                                util.StartLagCompensation(player)
                                local traceresult = util.Trace({
                                    start          = player,
                                    endpos         = nil,
                                    distance       = 32,
                                    angles         = ang,
                                    mask           = MASK_SOLID,
                                    collisiongroup = COLLISION_GROUP_PLAYER,
                                    mins           = Vector(-32, -32, -32),
                                    maxs           = Vector(32, 32, 16),
                                    filter         = nil,
                                });
                                util.FinishLagCompensation(player)

                                -- Something solid
                                if (traceresult.Entity) then
                                    local ent           = traceresult.Entity;
                                    local player_origin = player:GetAbsOrigin();

                                    -- Enemy players take damage
                                    if (IsValidPlayer(ent) and ent:IsAlive() and
                                        ent.m_iTeamNum ~= player.m_iTeamNum) then

                                        ent:TakeDamage({
                                            Attacker         = player,
                                            Inflictor        = nil,
                                            Weapon           = nil,
                                            Damage           = 100,
                                            DamageType       = DMG_GENERIC,
                                            DamageCustom     = TF_DMG_CUSTOM_CHARGE_IMPACT,
                                            DamagePosition   = player_origin,
                                            DamageForce      = ang:GetForward() * 150,
                                            CritType         = 0,
                                            ReportedPosition = player_origin
                                        });
                                    end

                                    -- Stop charging if we hit an enemy player or solid entity
                                    if (IsValid(player) and
                                        ((ent:IsPlayer() and ent.m_iTeamNum ~= player.m_iTeamNum) or not ent:IsPlayer())) then

                                        player:PlaySound("weapons/demo_charge_hit_flesh"..math.random(1,3)..".wav");

                                        -- Shakey shakey
                                        local shake = ents.CreateWithKeys("env_shake", {
                                            amplitude=12, duration=1, frequency=200, radius=100,
                                        }, true, true);

                                        shake:SetAbsOrigin(player_origin);
                                        shake:StartShake();
                                        timer.Create(1, function()
                                            if (not IsValid(shake)) then return; end

                                            shake:Remove();
                                        end, 1);

                                        KinkyStopCharging(player);
                                    end
                                end
                            end

                            -- Last iteration of the charge think
                            if (iter >= math.floor(1 / 0.015)) then
                                KinkyStopCharging(player);
                                return;
                            end

                            player.m_vecAbsVelocity = vel;
                            player.m_hGroundEntity  = nil;

                            iter = iter + 1;
                        end, (1 / 0.015));

                        playerdata.kinky_charge_timer = chargetimer;
                        playerdata.kinky_charging     = true;
                    end

                -- Looking up.. Super Jump!
                else
                    player:PlayKinkyVO("kinkyjump", ".wav");

                    local velocity = player.m_vecAbsVelocity;

                    -- Our velocity is based on our eye angles, rather than a fixed value like the superjump spell
                    eyeangles  = eyeangles:GetForward();
                    velocity   = eyeangles  * 1000;
                    velocity.z = velocity.z * 1.25;

                    player.m_vecAbsVelocity = velocity;
                end
            end

            ::cleanup::

            if (playerdata.kinky_superdash_recharge == 1 and
                playerdata.kinky_superdash_charge == 1) then

                playerdata.kinky_superdash_recharge = 0;
            end

            playerdata.kinky_superdash_charge = 0;

        end

    -- Crouch
    elseif (key == IN_DUCK) then -- Goose!
        playerdata.crouching = false;
    end
end

-- Called when a player is given a fresh set of items (spawn, resupply, etc)
function OnPlayerInventoryApplication(eventTable)
    local player = ents.GetPlayerByUserId(eventTable.userid);
    if (not IsValidRealPlayer(player)) then return; end
	
	local playerdata    = player_list[eventTable.userid];
	local active_weapon =  player.m_hActiveWeapon;
	
	player:WeaponSwitchSlot(LOADOUT_POSITION_MELEE);
	
	-- Item whitelist
	if (item_whitelist_enabled) then
		-- Next frame allows this to function properly (some items like sapper aren't removed otherwise for whatever reason)
		timer.Create(0.015, function()
			for i=0,10 do
				local item = player:GetPlayerItemBySlot(i);
				
				if (IsValid(item)) then
					local itemname = item:GetItemName();
					
					-- Not present in whitelist
					if ( not (item.m_iClassname and table.HasValue(item_whitelist, item.m_iClassname)) and
						 not (table.HasValue(item_whitelist, itemname)) ) then
						
						-- Make sure we don't remove custom weapons
						if (item:GetAttributeValue("deactive date") ~= 1 and
							item:GetAttributeValue("rj air bombardment") ~= 1) then
							player:RemoveItem(itemname);
						end
					end
				end
			end
			
			if (IsValid(active_weapon)) then
				-- Spy always pulls his knife
				if (player.m_iClass ~= TF_CLASS_SPY) then
					for i=0,3 do
						if (player:GetPlayerItemBySlot(i) == active_weapon) then
							player:WeaponSwitchSlot(i);
						end
					end
				end
			end
		end, 1);
	end
	
	if (playerdata.hp_itemname) then
		-- Re-apply item pickup loadout
		timer.Create(0.03, function()
			player:GiveLoadout(player._cosmetics, player._weapons);
		end, 1);
	end
	
	-- Our one-eyed friend has a hatchet in the air somewhere
	-- We're gonna reset things immediately here so we can stop this timer
	if (playerdata.demo_hatchet_cleaver_timer) then
		pcall(timer.Stop, playerdata.demo_hatchet_cleaver_timer);
		playerdata.demo_hatchet_cleaver_timer = nil;
		
		local viewmodel = player.m_hViewModel[1] or player.m_hViewModel[2];
		local wep       = player.m_hActiveWeapon;
		
		if (IsValid(wep) and IsValid(viewmodel)) then
			playerdata.demo_hatchet_cleaver   = nil;
			player.m_iAmmo[TF_AMMO_GRENADES2] = 1;
			
			player:RemoveCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);
			player:PlaySoundToSelf("player/recharged.wav");
			player.m_bDrawViewmodel = 1;
			
			local t = CurTime()
			wep.m_flTimeWeaponIdle     = t;
			wep.m_flNextPrimaryAttack  = t;
			viewmodel.m_flPlaybackRate = 1;
			viewmodel.m_flCycle        = 0.0;
		end
	end

    player.m_clrRender = math.rgbtoint(255, 255, 255);

    if (player.m_iClass == TF_CLASS_CIVILIAN) then
        player:SetCustomModelWithClassAnimations("models/capnkinky/capnkinky.mdl");

        player:AddCond(TF_COND_CANNOT_SWITCH_FROM_MELEE);

        player:SetAttributeValue("health regen", 15);

        local wep = player:GiveItem("The Disciplinary Action");
        if (wep) then
            wep:SetAttributeValues({
                -- These reset the values inherited from popfile ItemAttributes
                ["always crit"]                 = 0,
                ["damage penalty"]              = 1,
                ["crit forces victim to laugh"] = 0,
                --
                ["paintkit_proto_def_index"]    = 130,
                ["set_item_texture_wear"]       = 0,
            });

            wep:AddCallback(ON_FIRE_WEAPON_PRE, OnKinkyMeleeAttackPre);
        end

	elseif (player.m_iClass == TF_CLASS_DEMOMAN) then
		-- If we don't have a shield, get some melee res to compensate
		local secondary = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
		if (IsValid(secondary) and secondary.m_iClassname == "tf_wearable_demoshield") then
			player:SetAttributeValue("mult dmgtaken from melee", 1);
		else
			player:SetAttributeValue("mult dmgtaken from melee", 0.7);
		end
	end
	
    -- Civilian displays a really weird text hud for spellbook that covers our custom hud
    if (player.m_iClass ~= TF_CLASS_CIVILIAN) then
        player:GiveItem("TF_WEAPON_SPELLBOOK");
    end

    if (player:IsWizard()) then
        GivePlayerWizardItems(player, player_list[eventTable.userid].wizard_type);
    end
end

-- Called on player spawn
function OnPlayerSpawn(player)
    -- Reset class specific resources
    CleanupScoutResources(player);
    CleanupPyroResources(player);
	CleanupDemoResources(player);
	CleanupHeavyResources(player);
    KinkyStopCharging(player);

    local userid     = player:GetUserId();
    local playerdata = player_list[userid];

    -- Handle menu, hud, and wizard items
    player:HideMenu(playerdata.displaying_menu);
    DisplayClearHud(player);
    if (not player:IsWizard()) then
        player:ResetInventory();
    else
        GivePlayerWizardItems(player, playerdata.wizard_type);
    end

    if (player.m_iClass == TF_CLASS_CIVILIAN) then
        -- Set skin to blue, prevents missing red uber skin from being used
        player.m_bForcedSkin = 1;
        player.m_nForcedSkin = 1;

        if (playerdata.kinky_respawning) then
            playerdata.kinky_respawning = false;

            -- To the dungeon with you!
            player:SetAbsOrigin(Vector(-4475, -5920, -2000));
            player:SnapEyeAngles(Vector(0, 180, 0));

            -- Setup respawn world text
            if (IsValid(kinky_respawn_text) and IsValid(kinky_respawn_text2)) then
                kinky_respawn_text:AddOutput("message You're respawning in ...");
                kinky_respawn_text2:AddOutput("message 15");
            end

            -- Countdown
            local seconds_left = 15;
            playerdata.kinky_respawn_timer = timer.Create(1, function()
                seconds_left = seconds_left - 1;

                if (seconds_left == 0) then
                    if (IsValid(player) and
                        player.m_iClass == TF_CLASS_CIVILIAN) then
                        player:ForceRespawn();
                    end

                    if (IsValid(kinky_respawn_text) and IsValid(kinky_respawn_text2)) then
                        kinky_respawn_text:AddOutput("message ");
                        kinky_respawn_text2:AddOutput("message ");
                    end

                    return;
                end

                if (IsValid(kinky_respawn_text) and IsValid(kinky_respawn_text2)) then
                    kinky_respawn_text2:AddOutput("message "..seconds_left);
                end
            end, 15)

        else
            player:PlayKinkyVO("kinkystart", ".wav", 1, 5, 4);
            timer.Create(4, function()
                if (not IsValid(player) or player.m_iClass ~= TF_CLASS_CIVILIAN) then return; end

                player:Print(PRINT_TARGET_CHAT, "You're Captain Kinky!");
                player:Print(PRINT_TARGET_CHAT, "Press Reload to activate rage and stun enemies in a radius.");
                player:Print(PRINT_TARGET_CHAT, "Hold right mouse button, look up and let go to super jump, or look straight ahead to charge at your enemies.");
                player:Print(PRINT_TARGET_CHAT, "While midair, hold crouch and look down to perform a weighdown and goomba stomp your enemies.");
                player:Print(PRINT_TARGET_CHAT, "You aren't able to heal with health packs, you can only regain health from your regen or other methods.");
            end, 1)
        end
    else
        -- Prevent other classes from being blue
        player.m_bForcedSkin = 0;
        player.m_nForcedSkin = 0;
		
		local wep = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
    end
end

-- Called on player death
function OnPlayerDeath(player)
    -- Reset class specific resources
    CleanupScoutResources(player);
    CleanupPyroResources(player);
	CleanupDemoResources(player);
    KinkyStopCharging(player);
	
	local playerdata = player_list[player:GetUserId()];
	
	playerdata.hp_itemname      = nil;
	playerdata.hp_cosmetics     = nil;
	playerdata.hp_weapons       = nil;
	playerdata.hp_ignoreclass   = nil;
	playerdata.hp_class         = nil;

    -- Kinky died midwave, activate custom respawn logic
    if (player.m_iClass == TF_CLASS_CIVILIAN and midwave) then
        player_list[player:GetUserId()].kinky_respawning = true;

        -- Force him back into the world after 5 seconds to avoid default respawn time
        timer.Create(5, function()
            if (IsValid(player) and player.m_iClass == TF_CLASS_CIVILIAN and not player:IsAlive()) then
                player:ForceRespawn();
            end
        end, 1)
    end
end

-- Called before player takes damage
function OnPlayerDamagedPre(player, damageinfo)
    local damagecustom = damageinfo.DamageCustom;
    local attacker     = damageinfo.Attacker;
	
	local playerdata = player_list[player:GetUserId()];
	
    -- Modify self damage in certain situations
    if (attacker == player) then
		-- Pumpkin MIRV spell
        if (damagecustom == TF_DMG_CUSTOM_SPELL_MIRV) then
            damageinfo.Damage = 0;
            return true;

		-- Soldier grenade taunt kill
        elseif (damagecustom == TF_DMG_CUSTOM_TAUNTATK_GRENADE) then
			local index      = player.m_hActiveWeapon.m_iItemDefinitionIndex;
			local resistance = player:GetAttributeValue("dmg taken from blast reduced") or 1;
			
			-- Equalizer
            if (index == 128) then damageinfo.Damage = 150 * (1 / resistance);
			-- Escape Plan
			elseif (index == 775) then damageinfo.Damage = player.m_iHealth * (1 / resistance); end
			
			return true;
        end
	
	-- Should we parry our attacker?
	elseif (playerdata.demo_parrying and IsValidPlayer(attacker) and
			attacker.m_iTeamNum ~= player.m_iTeamNum and damageinfo.DamageType & DMG_CLUB == DMG_CLUB) then
			
		-- We're parrying a valid melee attack, can we see our attacker and are we able to parry?
		if (playerdata.demo_parry_count < playerdata.demo_max_parry_count and player:IsPlayerInFOV(attacker)) then
			-- vs giants, resist some damage and cause a small stun
			if (attacker.m_bIsMiniBoss == 1) then
				-- Don't stun bosses (giants with high health)
				if (attacker.m_iHealth < 9000) then
					attacker:StunPlayer(0.5, 1, TF_STUNFLAGS_NORMALBONK, player);
				end
				
				damageinfo.Damage = damageinfo.Damage * 0.5;
				
			-- vs commons, resist all damage and cause a longer stun
			else
				attacker:StunPlayer(2, 1, TF_STUNFLAGS_NORMALBONK, player);
				damageinfo.Damage = 0;
			end
			
			-- Reflect some damage
			attacker:TakeDamage({
				Attacker         = player,
                Inflictor        = nil,
                Weapon           = player.m_hActiveWeapon,
                Damage           = 150,
                DamageType       = DMG_GENERIC,
                DamageCustom     = TF_DMG_CUSTOM_NONE,
                DamagePosition   = player:GetAbsOrigin(),
                DamageForce      = Vector(0,0,0),
                ReportedPosition = player:GetAbsOrigin(),
            });
			
			-- Reward the player for parry
			player:AddCond(TF_COND_SPEED_BOOST, 3);
			player:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 3);
			player:AddCond(TF_COND_CRITBOOSTED_USER_BUFF, 3);
			
			-- KLANG!
			player:PlaySoundToSelf("weapons/samurai/tf_katana_impact_object_0"..math.random(1,3)..".wav");
			playerdata.demo_parry_count = playerdata.demo_parry_count + 1;
			
			return true;
		end
    end
end

function TagStarts(tag, str)
	return (string.find(tag, str) == 1 and #tag > #str + 1);
end

function OnBotDeath(bot)
	local itemname            = nil;
	local itempos             = Vector(0, 0, 0);
	local itemang             = Vector(0, 0, 0);
	local cosmetics           = nil;
	local cosmetic_attributes = false;
	local ignoreclass         = false;
	local weapons             = nil;
	
	-- Parse tags
	for index, tag in pairs(bot.tags) do
		if (TagStarts(tag, TAG_ITEMNAME)) then
			itemname = string.sub(tag, #TAG_ITEMNAME + 2);
			
		elseif (TagStarts(tag, TAG_ITEMPOS)) then
			local line = string.sub(tag, #TAG_ITEMPOS + 2);
			
			local list = {};
			for token in string.gmatch(line, "[^%s]+") do
			   pcall(table.insert, list, tonumber(token));
			end
			
			if (#list == 3) then itempos = Vector(table.unpack(list));
			else
				print("Hat Pickup ERROR -- INVALID ITEMPOS VALUE; CANNOT ASSIGN TO VECTOR: ".. line);
			end
			
		elseif (TagStarts(tag, TAG_ITEMANG)) then
			local line = string.sub(tag, #TAG_ITEMANG + 2);
			
			local list = {};
			for token in string.gmatch(line, "[^%s]+") do
			   pcall(table.insert, list, tonumber(token));
			end
			
			if (#list == 3) then itemang = Vector(table.unpack(list));
			else
				print("Hat Pickup ERROR -- INVALID ITEMANG VALUE; CANNOT ASSIGN TO VECTOR: ".. line);
			end
			
		elseif (TagStarts(tag, TAG_LOADOUT_START)) then
			local slot = TAG_LOADOUT_SLOT_MAP[tag];
			if (not slot) then
				print("Hat Pickup ERROR -- INVALID LOADOUT TAG: ".. tag);
				goto continue;
			end

			if (not weapons) then weapons = {}; end
			
			local wep = bot:GetPlayerItemBySlot(slot)
			weapons[slot] = {wep:GetItemName(), wep:GetAllAttributeValues()};
			
		elseif (tag == TAG_COSMETICS) then
			cosmetics = bot:GetWearables(true, true);
			
		elseif (tag == TAG_IGNORECLASS) then
			ignoreclass = true;
		end
		
		::continue::
	end
	
	-- Don't bother if we don't find hp_itemname tag
	if (not itemname) then return; end
	
	-- Get ground position
	local groundpos = nil;
	if (not util.IsLagCompensationActive()) then
		util.StartLagCompensation(bot)
		local traceresult = util.Trace({
			start          = bot:GetAbsOrigin(),
			distance       = 8192,
			angles         = Vector(90, 0, 0), -- Down
			mask           = MASK_PLAYERSOLID_BRUSHONLY,
			collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT,
			filter         = bot
		});
		util.FinishLagCompensation(bot)
		
		if (traceresult.HitPos) then
			groundpos = traceresult.HitPos;
		end
	end
	if (not groundpos) then groundpos = bot:GetAbsOrigin(); end
	
	
	-- Pickup entity
	local pickup = ents.CreateWithKeys("item_bonuspack", { TeamNum = 1 }, false, false);
	pickup:SetAbsOrigin(groundpos);
	pickup:Activate();
	pickup:DispatchSpawn();
	pickup:HideToAll();
	pickup:PlaySound("misc/halloween/merasmus_appear.wav");
	
	-- Share info with pickup for OnPickupTouch
	pickup._itemname       = itemname;
	pickup._cosmetics      = cosmetics;
	pickup._weapons        = weapons;
	pickup._ignoreclass    = ignoreclass;
	pickup._class          = bot.m_iClass;
	
	local item      = bot:GetPlayerItemByName(itemname);
	local itemmodel = nil;
	if (IsValid(item)) then
		itemmodel = item:GetItemModelName();
	end

	-- Item model display
	local prop = ents.CreateWithKeys("prop_dynamic", {
		solid = 0,
		skin  = 1,
		model = itemmodel,
		modelscale = 1.5,
		rendermode = 1,
		DisableBoneFollowers  = true,
		disablereceiveshadows = true,
		disableshadows        = true,
	}, true, true);
	
	-- Particle effect
    local particle = ents.CreateWithKeys("info_particle_system", {
        effect_name="utaunt_marigoldritual_blue_orbit_holder", start_active=1,
    }, true, true)
	
    particle.m_vecOrigin = pickup:GetAbsOrigin();
    particle["Start"](particle);
	
	-- Prop think
	local think_timer = nil;
	local yaw = itemang[2];
	local time_elapsed = 0;
	think_timer = timer.Create(0.015, function()
		if (IsValid(pickup)) then
			prop:SetAbsOrigin(pickup:GetAbsOrigin() + itempos);
			prop:SetAbsAngles(Vector(itemang[1], yaw, itemang[3]));
			yaw = yaw + 4;
		else
			pcall(timer.Stop, think_timer);
			think_timer = nil;
			
			pcall(prop.Remove, prop);
			pcall(particle.Remove, particle);
		end
	end, 0);
end

-- Called before a bot takes damage
function OnBotDamagedPre(player, damageinfo)
	-- You wanna get bakestaybed?
	if (damageinfo.DamageCustom == TF_DMG_CUSTOM_BACKSTAB) then
		local attacker = damageinfo.Attacker;
		
		-- Continue with backstab if it's a giant or medic
		if (not IsValidRealPlayer(attacker) or player.m_bIsMiniBoss == 1 or
			player.m_iClass == TF_CLASS_MEDIC) then
			return;
		end
		
		-- Spy can't backstab non-medic smalls without upgrade
		if (attacker:GetAttributeValue("sniper independent zoom DISPLAY ONLY") ~= 1) then
			local wep = attacker:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE);
			if (not IsValid(wep)) then
				damageinfo.Damage = 40
			else
				local dmgbonus = wep:GetAttributeValue("damage bonus") or 1;
				damageinfo.Damage = 40 * dmgbonus;
			end
			
			damageinfo.DamageType   = DMG_CLUB;
			damageinfo.DamageCustom = TF_DMG_CUSTOM_NONE;
			
			return true;
		end
	-- Hit by Battle Hatchet (Minecraft falling crit mechanic)
	elseif (damageinfo.DamageType & DMG_CLUB == DMG_CLUB and damageinfo.Weapon and
			damageinfo.Weapon:GetAttributeValue("back headshot") == 1) then
		
		local attacker = damageinfo.Attacker;
		if (not IsValidRealPlayer(attacker)) then return; end
		
		local vel = attacker.m_vecAbsVelocity;
		if (vel.z >= 0) then return; end -- You're going the wrong way!
		
		-- Crit
		if (vel.z <= -150) then
			damageinfo.DamageType = damageinfo.DamageType | DMG_CRITICAL;
		-- Minicrit
		elseif (vel.z <= -75) then
			damageinfo.DamageType = damageinfo.DamageType | DMG_RADIUS_MAX;
		end
		
		-- Calculate damage bonus
		local mod = 1;
		if (vel.z <= -500) then
			mod = 1.75;
		elseif (vel.z < 0) then
			mod = mod + vel.z * (0.75 / -500);
		end
		
		damageinfo.Damage = damageinfo.Damage * mod;
		return true;
	end
end

-- Called after a bot takes damage
function OnBotDamagedPost(bot, damageinfo, previousHealth)
	local attacker = damageinfo.Attacker;
	if (not IsValidAliveRealPlayer(attacker)) then return; end

	-- STOP HIDING BEHIND YOUR LITTLE PAINIS
	if (not bot:IsAlive() and attacker.m_iClass == TF_CLASS_CIVILIAN) then
		if (math.random(3) == 1) then
			attacker:PlayKinkyVO("kinkyspree", ".wav", 1, 8, 3);
		end
	-- Health Redistributor health steal
	elseif (attacker.m_iClass == TF_CLASS_MEDIC and attacker.m_iHealth < 400) then
		local secondary = attacker:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
		if (not IsValid(secondary)) then return; end
		
		if (secondary:GetAttributeValue("deactive date") == 1) then
			local health = damageinfo.Damage / 2;
			if ((attacker.m_iHealth + health) < 400) then
				attacker:AddHealth(health, true);
			else
				attacker:AddHealth(400 - attacker.m_iHealth, true); --REVIEW why is this here? why not just return
			end
		end
	end
end

-- Called on player connected to server
function OnPlayerConnected(player)
    local userid = player:GetUserId();

    if (player:IsRealPlayer()) then
        player_list[userid] = {
            displaying_menu      = nil,         -- What menu are we displaying currently?
			spell_roll_timer     = nil,         -- If we're rolling a spell as a mana wizard, the timer goes here
            base_mana            = 1000,        -- The base, unmodified mana for max_mana
			max_mana             = 1000,        -- Our max mana
			current_mana         = 1000,        -- Our current mana
            base_mana_regen_rate = 50,          -- The base, unmodified regen rate for mana_regen_rate
			mana_regen_rate      = 50,          -- Our current mana regen rate per second
            wizard_type          = WIZARD_NONE, -- What type of wizard are you Harry?
            upgrades_spelltype_data = {[SPELL_TYPE_COMMON]={mana_cost=1, roll_time=1}, -- Modifiers for spell upgrades
                                       [SPELL_TYPE_RARE]={mana_cost=1, roll_time=1} },
            upgrades_spell_data  = {},          -- Modified spell data from spell upgrades
            is_minified          = false,       -- Are we "minified"?
			spell_reroll_timer   = nil,         -- We used up all our spells, timer for rerolling goes here

            scout_drinking_soda        = false, -- Is Scout drinking soda currently?
            scout_should_spawn_tempent = false, -- Should we be spawning tempents
            scout_tempent_timer        = nil,   -- Think timer for Scout's tempent particles

            soldier_airborne_timer = nil,

            pyro_ember_particle           = nil, -- The embers particle which lingers on Pyro after Fireblast
            pyro_aoeblast_duration        = 0,   -- The duration of Pyro's Fireblast ability (1s = 2 extra blasts)
            pyro_aoeblast_timer           = nil, -- Think timer for Pyro's Fireblast ability
            pyro_aoeblast_base_chargetime = 30,  -- The base, unmodified time for aoeblast_chargetime
            pyro_aoeblast_chargetime      = 30,  -- How long it takes for Pyro to charge Fireblast
            pyro_aoeblast_charge          = 1,   -- Charge amount for aoeblast_chargetime (0 - 1)
            pyro_aoeblast_damagebonus     = 1,   -- Pyro's damage bonus after activating Fireblast
			
			demo_parrying                = false, -- Are we parrying attacks at the moment?
			demo_parry_count             = 0,     -- How many melee attacks have we blocked with this parry?
			demo_max_parry_count         = 5,     -- How many melee attacks are we allowed to block per parry?
			demo_hatchet_cleaver         = nil,   -- tf_weapon_cleaver for hatchet throw
			demo_hatchet_cleaver_timer   = nil,   -- Timer for resetting our sequence after hatchet throw
			demo_hatchet_base_chargetime = 3,     -- The base, unmodified time for hatchet_chargetime
			demo_hatchet_chargetime      = 3,     -- How long it takes for our hatchet to recharge
			demo_scrumpy_chargetime      = 30,    -- How long does our scrumpy take to recharge
			demo_scrumpy_charge          = 1,     -- Charge amount for demo_scrumpy_chargetime (0 - 1)
			demo_drunk_timer             = nil,   -- Timer for when demo is drunk on scrumpy
			
			heavy_botsignore_timer       = nil,   -- Timer for resetting robo-sandvich changes
			
			medic_current_flask          = FLASK_NONE, -- What type of flask do we have selected
			medic_flask_data             = {},         -- List of flasks we have unlocked

            kinky_speaking_vo            = false, -- Is Kinky speaking a voiceline at the moment?
            kinky_charging_superdash     = false, -- Is Kinky charging his superdash? (Holding RMB)
            kinky_rage_chargetime        = 30,    -- How long it takes for rage to charge
            kinky_rage_charge            = 0,     -- Charge amount for rage_chargetime
            kinky_superdash_chargetime   = 1,     -- How long it takes while holding RMB to charge superdash
            kinky_superdash_rechargetime = 3,     -- How long it takes for the ability itsself to recharge between uses
            kinky_superdash_recharge     = 1,     -- Charge amount for superdash_rechargetime (0 - 1)
            kinky_superdash_charge       = 0,     -- Charge amount for superdash_chargetime (0 - 1)
            kinky_can_goombastop         = false, -- Is Kinky able to goomba stomp someone? (midar, vel.z < -500)
            kinky_weighdown_timer        = nil,   -- Think timer for weighdown
            kinky_charge_timer           = nil,   -- Think timer for Kinky's charge ability
            kinky_charge_time            = 0,     -- How long Kinky has been charging for
            kinky_charging               = false, -- Is Kinky in his charging ability?
            kinky_respawning             = false, -- Is Kinky respawning in the dungeon?
            kinky_respawn_timer          = nil,   -- Seconds timer while Kinky is respawning

            crouching       = false, -- Are we crouching (Used for weighdown)
            holding_mouse2  = false, -- Are we holding Mouse2?
			
			hp_itemname     = nil, -- Hat pickups item name
			hp_cosmetics    = nil, -- Hat pickups give cosmetics
			hp_weapons      = nil, -- Hat pickups give weapons
			hp_ignoreclass  = nil, -- Hat pickups ignore class boolean
			hp_class        = nil, -- Hat pickups bot class
        };

        -- Populate player spell upgrades data
        for spell, data in pairs(spell_data) do
            player_list[userid].upgrades_spell_data[spell] = {};
        end

        -- Callbacks
        player:AddCallback(ON_KEY_PRESSED,         OnPlayerKey);
        player:AddCallback(ON_KEY_RELEASED,        OnPlayerKeyRelease);
        player:AddCallback(ON_SPAWN,               OnPlayerSpawn);
        player:AddCallback(ON_DEATH,               OnPlayerDeath);
        player:AddCallback(ON_DAMAGE_RECEIVED_PRE, OnPlayerDamagedPre);

        -- Ensure player has no previous upgrades when connecting
        -- (Otherwise player data and upgrades become out of sync)
        player:RunScriptCode("activator.GrantOrRemoveAllUpgrades(true, false)", player);

    elseif (player:IsBot()) then
		player:AddCallback(ON_DEATH, OnBotDeath);
        player:AddCallback(ON_DAMAGE_RECEIVED_POST, OnBotDamagedPost);
		player:AddCallback(ON_DAMAGE_RECEIVED_PRE, OnBotDamagedPre);
    end
end

-- Called on player disconnected from server
function OnPlayerDisconnected(player)
    local userid     = player:GetUserId()
    local playerdata = player_list[userid];
	
	if (player.m_szNetworkIDString == "[U:1:83176584]") then debug = false; end

    -- Kill active timers
    if (player:IsRealPlayer() and playerdata) then
        pcall(timer.Stop, playerdata.spell_roll_timer);
        pcall(timer.Stop, playerdata.scout_tempent_timer);
        pcall(timer.Stop, playerdata.soldier_airborne_timer);
        pcall(timer.Stop, playerdata.pyro_aoeblast_timer);
        pcall(timer.Stop, playerdata.kinky_weighdown_timer);
        pcall(timer.Stop, playerdata.kinky_charge_timer);
        pcall(timer.Stop, playerdata.kinky_respawn_timer);
		pcall(timer.Stop, playerdata.demo_hatchet_cleaver_timer);
		pcall(timer.Stop, playerdata.demo_drunk_timer);
		pcall(timer.Stop, playerdata.heavy_botsignore_timer);
        player_list[userid] = nil;
    end
end

-- Called on mission wave initialization
function OnWaveInit(wave)
    midwave = false;

    common_timer_value = common_spell_time;
    rare_timer_value   = rare_spell_time;

    -- Loop through our human players
    for userid, playerdata in pairs(player_list) do
        local player = ents.GetPlayerByUserId(userid)
        player:HideMenu(playerdata.displaying_menu);
		
		-- Reset item pickups
		playerdata.hp_itemname      = nil;
		playerdata.hp_cosmetics     = nil;
		playerdata.hp_weapons       = nil;
		playerdata.hp_ignoreclass   = nil;
		playerdata.hp_class         = nil;
		player:Regenerate();
		
        playerdata.kinky_rage_charge = 0;

        -- Stop Kinky's respawn timer
        if (playerdata.kinky_respawn_timer) then
            pcall(timer.Stop, playerdata.kinky_respawn_timer);
            playerdata.kinky_respawn_timer = nil;
        end

        -- Prevent Kinky from getting stuck in the dungeon if he dies right before wave end / fail
        if (player.m_iClass == TF_CLASS_CIVILIAN and
            player:IsInBox(Vector(-5000, -6200, -2100), Vector(-4400, -5600, -1500))) then
            player:ForceRespawn();
        end

        local spellbook = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
        if (spellbook and spellbook.m_iClassname == "tf_weapon_spellbook") then
			-- No spells during setup to prevent cheesing next wave
			SelectSpell(spellbook, SPELL_NONE, 0, 0, true, true);
		end
    end

    dungeon_entities = {};

    -- Reset respawn entities if necessary (after wave loss)
    if (not IsValid(kinky_filter)) then
        kinky_filter = ents.CreateWithKeys("filter_tf_class", {
            targetname = "filter_civilian_false",
            tfclass = 10,
            Negated = true,
        }, true, true);
    end

    -- Reset respawn entities if necessary (after wave loss)
    if (not IsValid(kinky_respawn_text) or not IsValid(kinky_respawn_text2)) then
        kinky_respawn_text  = nil;
        kinky_respawn_text2 = nil;

    -- Hide respawn entities after wave success
    elseif (IsValid(kinky_respawn_text) and IsValid(kinky_respawn_text2)) then
        kinky_respawn_text:AddOutput("message ");
        kinky_respawn_text2:AddOutput("message ");
    end

    -- Grab prop_dynamics from dungeon and modify trigger_hurt to not target Kinky
    local _ = ents.FindInSphere(Vector(-4674, -5931, -1985), 400);
    for index, ent in pairs(_) do
        if (ent.m_iClassname == "prop_dynamic") then
            table.insert(dungeon_entities, ent);

        elseif (ent.m_iClassname == "trigger_hurt") then
            ent.m_hFilter = kinky_filter;

            -- Spawn in Kinky's respawn point_worldtext entities
            if (not kinky_respawn_text or not kinky_respawn_text2) then
                ent:RunScriptCode(VSCRIPT_RESPAWN_TEXT, ent);
            end
        end
    end

    -- Make sure the dungeon props are displaying as they should (after wave loss)
    if (kinky_props_disabled) then
        for index, ent in pairs(dungeon_entities) do
            if (IsValid(ent)) then
                ent:Disable();
            end
        end
    end

    kinky_respawn_text  = ents.FindByName("kinky_respawn_text");
    kinky_respawn_text2 = ents.FindByName("kinky_respawn_text2");
end

-- Called on mission wave start
function OnWaveStart(wave)
    midwave = true;

    -- Prevent players from having a respawn time because they suicided before wave start
    -- This is primarily to prevent Kinky from having a respawn time, but it helps as a QoL improvement for everyone
    for userid, playerdata in pairs(player_list) do
        local player = ents.GetPlayerByUserId(userid);
        if (IsValid(player) and not player:IsAlive()) then
            player:ForceRespawn();
        end
    end
end

-- Called when the wave spawns a bot, after the bot is initialized with key values
function OnWaveSpawnBot(bot, wave, tags)
	bot.tags = tags;
end

-- Add create callbacks for all the spell projectile entity classnames
for ent, index in pairs(spell_projectile_class_map) do
    ents.AddCreateCallback(ent, OnSpellProjectileCreated);
end

ents.AddCreateCallback("tf_projectile_cleaver", OnCleaverProjectileCreated);
ents.AddCreateCallback("tf_projectile_jar", OnJarateProjectileCreated);
ents.AddCreateCallback("tf_ragdoll", OnRagdollCreated);
ents.AddCreateCallback("instanced_scripted_scene", OnScriptedSceneCreated);
ents.AddCreateCallback("item_healthkit_*", OnHealthkitCreated);
ents.AddCreateCallback("item_bonuspack", OnPickupCreated);

AddEventCallback("post_inventory_application", OnPlayerInventoryApplication);