-- Fire a weapon mimic from a player's eye angles
function FireCustomWeaponMimic(player, keyvalues, playerattributes,
                               itemattributes, custommodel, customsound, customparticles)

    if (not IsValidRealPlayer(player)) then return; end

    local mimic = ents.CreateWithKeys("tf_point_weapon_mimic", keyvalues, true, true)
    mimic:SetOwner(player);

    local current_player_attributes = {};

    -- Populate current_player_attributes with attributes to be modified from playerattributes
    if (playerattributes) then
        for attr, val in pairs(playerattributes) do
            local currentattr = player:GetAttributeValue(attr);
            if (not currentattr) then
                -- We need to know later that this attribute needs to be modified, so we can't set it to nil
                current_player_attributes[attr] = "\0";
            else
                current_player_attributes[attr] = currentattr;
            end

            player:SetAttributeValue(attr, val);
        end
    end

    -- Modify mimic's weapon attributes
    if (itemattributes) then
        for index, attr in pairs(itemattributes) do
            mimic:AddWeaponAttribute(attr);
        end
    end

    -- Inherit owner eye angles
    local player_eye_angles = player:GetEyeAngles();
    if (not player_eye_angles) then player_eye_angles = Vector(0, 0, 0); end
    mimic:SetAbsAngles(player_eye_angles);

    -- Inherit owner eye origin
    local player_eye_origin = player:GetEyePos();
    mimic:SetAbsOrigin(player_eye_origin);

    -- Stuff to do when the mimic weapon fires
    function HandleMimicChanges(value, activator, caller)
        -- Add particle effects to the projectile
        local particleentities = {};
        if (customparticles) then
            for index, particlename in pairs(customparticles) do
                local particle = ents.CreateWithKeys("info_particle_system", {
                    effect_name=particlename, start_active=1,
                    ["$modules"]="fakeparent",
                }, true, true);

                table.insert(particleentities, particle);

                local origin = activator:GetAbsOrigin();
                particle.m_vecOrigin = origin;
                particle:SetFakeParent(activator);
                particle:Start();
            end
        end

        -- Set the projectile's model
        if (custommodel) then
            activator:SetModelSpecial(custommodel);
        end

        -- Kaboom
        activator:AddCallback(ON_REMOVE, function()
            -- Clean up particles
            for index, particle in pairs(particleentities) do
                particle:Remove();
            end

            -- Revert player's attributes
            for attr, val in pairs(current_player_attributes) do
                if (val == "\0") then
                    player:SetAttributeValue(attr, nil);
                else
                    player:SetAttributeValue(attr, val);
                end
            end
        end);
    end

    mimic:AddOutput("$OnFire popscript,$HandleMimicChanges,,0,-1");

    mimic:FireOnce();
    if (customsound) then
        player:PlaySoundToSelf(customsound);
    end

    mimic:Remove();
end

-- Spawn function for the Healing Aura spell
function SpellHealingAuraSpawn(player, spellbook)
    if (not IsValidRealPlayer(player)) then return; end

    local entities = ents.FindInSphere(player:GetAbsOrigin(), 96);
    for index, ent in pairs(entities) do
        if (IsValidPlayer(ent) and ent.m_iTeamNum == player.m_iTeamNum) then
            ent:AddCond(TF_COND_INVULNERABLE, 2);
            ent:AddCond(TF_COND_HALLOWEEN_QUICK_HEAL, 6);
        end
    end

    player:PlaySoundToSelf("Halloween.spell_overheal");
end

-- Spawn function for the Super Jump spell
function SpellSuperjumpSpawn(player, spellbook)
    if (not IsValidRealPlayer(player)) then return; end

    local velocity = player.m_vecAbsVelocity;

    if (velocity.z < 0) then velocity.z = 0; end
    velocity.z = (velocity.z + 500) * 2;
    if (velocity.z > 1500) then velocity.z = 1500; end

    player.m_vecAbsVelocity = velocity;

    player:PlaySoundToSelf("Halloween.spell_blastjump");
end

-- Spawn function for the Invisibility spell
function SpellInvisibilitySpawn(player, spellbook)
    if (not IsValidRealPlayer(player)) then return; end

    player:AddCond(TF_COND_STEALTHED_USER_BUFF, 5);
    player:SetAttributeValue("dmg taken increased", 0.5);
    player:PlaySoundToSelf("Halloween.spell_stealth");

    timer.Create(5, function()
        if (IsValid(player)) then return; end

        player:SetAttributeValue("dmg taken increased", 1);
    end, 1);
end

-- Spawn function for the Minify spell
function SpellMinifySpawn(player, spellbook)
    if (not IsValidRealPlayer(player)) then return; end

    local userid     = player:GetUserId();
    local playerdata = player_list[userid];

    if (playerdata.is_minified) then return; end

    playerdata.is_minified = true;
    local fire_rate = player:GetAttributeValue("fire rate bonus") or 1;
    local melee_res = player:GetAttributeValue("mult dmgtaken from melee") or 1;

    player:SetForcedTauntCam(1);
    player:AddCond(TF_COND_SPEED_BOOST, 8);

    player:SetAttributeValues({
        ["fire rate bonus"]          = 0.7,
        ["voice pitch scale"]        = 1.25,
        ["mult dmgtaken from melee"] = 0.6,
    });

    timer.Create(8, function()
        if (not IsValid(player)) then return; end

        player:SetForcedTauntCam(0);

        player:SetAttributeValues({
            ["fire rate bonus"]          = fire_rate,
            ["voice pitch scale"]        = 1,
            ["mult dmgtaken from melee"] = melee_res,
        });

        playerdata.is_minified = false;
    end, 1);
end

-- Fire function for the Crocket spell
function SpellCustomCrocketFired(value, activator, caller)
    local firetime    = CurTime();
	local think_timer = nil;
	think_timer = timer.Create(0.015, function()
        if (IsValid(activator)) then
            -- Explode after a short period
            if (CurTime() >= firetime + 5) then
                local origin = activator:GetAbsOrigin();
                util.ParticleEffect("rd_robot_explosion_smoke_linger", origin);
                activator:PlaySound("BaseExplosionEffect.Sound");

                -- Damage enemy players in the blast radius
                local entities = ents.FindInSphere(origin, 146);
                for index, ent in pairs(entities) do
                    if (IsValidAlivePlayer(ent) and ent.m_iTeamNum ~= activator.m_iTeamNum) then
                        ent:TakeDamage({
                            Attacker = activator.m_hOwnerEntity,
                            Inflictor = activator,
                            Weapon = nil,
                            Damage = 40,
                            DamageType = DMG_GENERIC,
                            DamageCustom = TF_DMG_CUSTOM_NONE,
                            DamagePosition = origin,
                            DamageForce = Vector(0,0,0),
                            ReportedPosition = origin,
                        });
                    end
                end

                activator:Remove();
                return;
            end

            local player = activator.m_hOwnerEntity;
            if (not IsValidRealPlayer(player)) then return; end

            -- Owner doesn't have homing rockets upgrade, don't continue
            if (not player:GetAttributeValue("sticky detonate mode")) then return; end

            local player_eye_angles = player:GetEyeAngles();
            if (not player_eye_angles) then player_eye_angles = Vector(90, 0, 0); end

            -- Fire trace from owner's eyes and set rocket's angles and velocity towards hit position
            if (not util.IsLagCompensationActive()) then
                util.StartLagCompensation(player)
                local traceresult = util.Trace({
                    start = player,
                    endpos = nil,
                    distance = 8192,
                    angles = player_eye_angles,
                    mask = MASK_SHOT,
                    collisiongroup = COLLISION_GROUP_PLAYER,
                    mins = Vector(0,0,0),
                    maxs = Vector(0,0,0),
                    filter = {player, activator},
                });
                util.FinishLagCompensation(player)

                if (traceresult.Hit and traceresult.HitPos) then
                    local target_angles = (traceresult.HitPos - activator:GetAbsOrigin()):ToAngles();
                    activator:SetAbsAngles(target_angles);
                    activator.m_vecAbsVelocity = target_angles:GetForward() * 1100;
                end
            end

        else
            -- Projectile is dead, stop thinking
            if (think_timer) then
                pcall(timer.Stop, think_timer);
                think_timer = nil;
            end
        end
    end, 0);
end

-- Spawn function for the Crocket spell
function SpellCustomCrocketSpawn(player, spellbook)
    FireCustomWeaponMimic(player, {
        TeamNum         = player.m_iTeamNum,
        ["$weaponname"] = "TF_WEAPON_ROCKETLAUNCHER",
        ["$OnFire"]     = "popscript,$SpellCustomCrocketFired,,0,-1",
        Crits           = true,
    }, nil, nil, nil, "Weapon_RPG.SingleCrit", nil);
end

-- Fire function for the Gravity Bomb spell
function SpellCustomGravityBombFired(value, activator, caller)
    -- We need to access the projectile's owner's team after it's been removed
    local caster      = activator.m_hOwnerEntity;
    local caster_team = caster.m_iTeamNum;

    activator:AddCallback(ON_REMOVE, function()
        local offset = Vector(0, 0, 70);
        activator:PlayParentedParticle("flaregun_energyfield_red", offset, 4);
        activator:PlayParentedParticle("dxhr_lightningball_parent_red", offset, 4);

        local epicenter = activator:GetAbsOrigin() + offset;

        -- Suck enemy players into epicenter for duration
        local entities = {};
        timer.Create(0.015, function()
            entities = ents.FindInSphere(epicenter, 180);
            for index, ent in pairs(entities) do
                if (IsValidAlivePlayer(ent) and ent.m_iTeamNum ~= caster_team) then
                        local player_origin = ent:GetAbsOrigin();

                        -- Ensure victim becomes airborne when at low velocity
                        if (not ent:IsMidair()) then
                            player_origin.z = player_origin.z + 32;
                            ent:SetAbsOrigin(player_origin);
                        end

                        local velocity_dir = (epicenter - player_origin):ToAngles();
                        local distance = epicenter:Distance(player_origin);
                        local player_velocity = velocity_dir:GetForward() * (distance ^ 1.25);

                        ent.m_vecAbsVelocity = player_velocity;
                end
            end
        end, math.round(2.1 / 0.015));

        -- Explode afterwards
        timer.Create(4.2, function()
            local origin = epicenter;
            origin.z     = origin.z - 35;

            util.ParticleEffect("rd_robot_explosion_smoke_linger", origin);
            PlaySound("BaseExplosionEffect.Sound", origin);

            -- Damage enemy players in the blast radius
            for index, ent in pairs(entities) do
                if (IsValidAlivePlayer(ent) and ent.m_iTeamNum ~= caster_team) then
                    ent:TakeDamage({
                        Attacker         = caster,
                        Inflictor        = nil,
                        Weapon           = nil,
                        Damage           = 300,
                        DamageType       = DMG_GENERIC,
                        DamageCustom     = TF_DMG_CUSTOM_NONE,
                        DamagePosition   = origin,
                        DamageForce      = Vector(0,0,0),
                        ReportedPosition = origin,
                    });

                    local velocity_dir   = Vector(math.random(-90, -45), math.random(-180, 180), 0);
                    velocity_dir         = velocity_dir:GetForward() * math.random(500, 1000);
                    ent.m_vecAbsVelocity = velocity_dir;
                end
            end
        end, 1);
    end)
end

-- Spawn function for the Gravity Bomb spell
function SpellCustomGravityBombSpawn(player, spellbook)
    FireCustomWeaponMimic(player, {
        TeamNum         = player.m_iTeamNum,
        ["$weaponname"] = "TF_WEAPON_GRENADELAUNCHER",
        ["$OnFire"]     = "popscript,$SpellCustomGravityBombFired,,0,-1",
        Crits           = true,
    },
    nil, { "Projectile speed decreased|0.7", },
    "models/empty.mdl", "Halloween.spell_lightning_cast", {"flaregun_energyfield_red"});
end

spell_data = {
    [SPELL_CHOOSING] = {
        name      = "...",
        charges   = 0,
        mana_cost = nil,
        roll_time = 0,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_NONE,
    },
    [SPELL_NONE] = {
        name      = "None",
        charges   = 0,
        mana_cost = nil,
        roll_time = 0,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_NONE,
    },
    [SPELL_FIREBALL] = {
        name      = "Fireball",
        charges   = 2,
        mana_cost = 300,
        roll_time = 2,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_BALLOBATS] = {
        name      = "Ball O' Bats",
        charges   = 2,
        mana_cost = 300,
        roll_time = 1,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_HEALINGAURA] = {
        name      = "Healing Aura",
        charges   = 2,
        mana_cost = 400,
        roll_time = 3,
        is_custom = true,
        fake_icon = SPELL_HEALINGAURA,
        SpawnFunction = SpellHealingAuraSpawn,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_PUMPKINMIRV] = {
        name      = "Pumpkin MIRV",
        charges   = 2,
        mana_cost = 300,
        roll_time = 2,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_SUPERJUMP] = {
        name      = "Superjump",
        charges   = 999,
        mana_cost = 100,
        roll_time = 1,
        is_custom = true,
        fake_icon = SPELL_SUPERJUMP,
        SpawnFunction = SpellSuperjumpSpawn,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_INVISIBILITY] = {
        name      = "Invisibility",
        charges   = 999,
        mana_cost = 200,
        roll_time = 1,
        is_custom = true,
        fake_icon = SPELL_INVISIBILITY,
        SpawnFunction = SpellInvisibilitySpawn,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_TELEPORT] = {
        name      = "Teleport",
        charges   = 2,
        mana_cost = 300,
        roll_time = 1,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_TESLABOLT] = {
        name      = "Tesla Bolt",
        charges   = 1,
        mana_cost = 2000,
        roll_time = 7,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_RARE,
    },
    [SPELL_MINIFY] = {
        name      = "Minify",
        charges   = 2,
        mana_cost = 300,
        roll_time = 1,
        is_custom = true,
        fake_icon = SPELL_MINIFY,
        SpawnFunction = SpellMinifySpawn,
        spell_type = SPELL_TYPE_RARE,
    },
    [SPELL_METEORSHOWER] = {
        name      = "Meteor Shower",
        charges   = 1,
        mana_cost = 2500,
        roll_time = 7,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_RARE,
    },
    [SPELL_SUMMONMONOCULUS] = {
        name      = "Summon Monoculus",
        charges   = 1,
        mana_cost = 1250,
        roll_time = 5,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_RARE,
    },
    [SPELL_SUMMONSKELETONS] = {
        name      = "Summon Skeletons",
        charges   = 1,
        mana_cost = 1250,
        roll_time = 5,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_RARE,
    },
    [SPELL_KARTBOXINGROCKET] = {
        name      = "Bumper Car Boxing Rocket",
        charges   = 5,
        mana_cost = 450,
        roll_time = 3,
        is_custom = false,
        fake_icon = nil,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_KARTBASEJUMP] = {
        name      = "Bumper Car Base Jump",
        charges   = 999,
        mana_cost = 200,
        roll_time = 2,
        is_custom = true,
        fake_icon = SPELL_KARTBASEJUMP,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_KARTOVERHEAL] = {
        name      = "Bumper Car Overheal",
        charges   = 2,
        mana_cost = 600,
        roll_time = 3,
        is_custom = true,
        fake_icon = SPELL_KARTOVERHEAL,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_KARTBOMBHEAD] = {
        name      = "Bumper Car Bomb Head",
        charges   = 2,
        mana_cost = 500,
        roll_time = 4,
        is_custom = true,
        fake_icon = SPELL_KARTBOMBHEAD,
        SpawnFunction = nil,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_CUSTOM_CROCKET] = {
        name      = "Crocket!",
        charges   = 3,
        mana_cost = 500,
        roll_time = 3,
        is_custom = true,
        fake_icon = SPELL_FIREBALL,
        SpawnFunction = SpellCustomCrocketSpawn,
        spell_type = SPELL_TYPE_COMMON,
    },
    [SPELL_CUSTOM_GRAVITYBOMB] = {
        name      = "Gravity Bomb",
        charges   = 1,
        mana_cost = 2500,
        roll_time = 7,
        is_custom = true,
        fake_icon = SPELL_TESLABOLT,
        SpawnFunction = SpellCustomGravityBombSpawn,
        spell_type = SPELL_TYPE_RARE,
    },
};

-- Retrieve appropriate spell data from either player spell upgrades data or spell_data
function GetSpellData(player, spell, customspell, data, shouldround)
    local playerspelldata     = player_list[player:GetUserId()].upgrades_spell_data;
    local playerspelltypedata = player_list[player:GetUserId()].upgrades_spelltype_data;

    local modvalue    = nil;
    local returnvalue = nil;

    -- customspell takes priority over spell

    -- Custom spell has player upgrade data
    if (customspell and playerspelldata[customspell] and playerspelldata[customspell][data]) then
        -- Modify spell data with spell *type* data (COMMON, RARE)
        modvalue = playerspelltypedata[spell_data[customspell].spell_type][data] or 1;
        returnvalue = modvalue * playerspelldata[customspell][data];

        if (shouldround) then returnvalue = math.round(returnvalue); end

    -- Custom spell has generic spell data
    elseif (customspell and spell_data[customspell] and spell_data[customspell][data]) then
        -- Modify spell data with spell *type* data (COMMON, RARE)
        modvalue = playerspelltypedata[spell_data[customspell].spell_type][data] or 1;
        returnvalue = modvalue * spell_data[customspell][data];

        if (shouldround) then returnvalue = math.round(returnvalue); end

    -- Spell has player upgrade data
    elseif (spell and playerspelldata[spell] and playerspelldata[spell][data]) then
        -- Modify spell data with spell *type* data (COMMON, RARE)
        modvalue = playerspelltypedata[spell_data[spell].spell_type][data] or 1;
        returnvalue = modvalue * playerspelldata[spell][data];

        if (shouldround) then returnvalue = math.round(returnvalue); end

    -- Spell has generic spell data
    elseif (spell_data[spell] and spell_data[spell][data]) then
        -- Modify spell data with spell *type* data (COMMON, RARE)
        modvalue = playerspelltypedata[spell_data[spell].spell_type][data] or 1;
        returnvalue = modvalue * spell_data[spell][data];

        if (shouldround) then returnvalue = math.round(returnvalue); end
    end

    return returnvalue;
end

-- Select a spell for a player's spellbook
function SelectSpell(spellbook, spell_index, charges, roll_time,
					 override_same_spell, override_same_charges)

    local player     = spellbook.m_hOwner;
    local userid     = player:GetUserId();
    local playerdata = player_list[userid];

    -- If we're rolling at the moment, stop the timer
	if (playerdata.spell_roll_timer) then
		pcall(timer.Stop, player_list[userid].spell_roll_timer)
		playerdata.spell_roll_timer = nil;
	end

    if (not player:IsWizard()) then return; end

    -- Use this when checking whether to override, otherwise custom spells can't
    -- switch to fireball because that's technically what they are
    local current_spell = spellbook.m_iSelectedSpellIndex;
    if (spellbook._m_iCustomSelectedSpellIndex) then
        current_spell = spellbook._m_iCustomSelectedSpellIndex;
    end

	-- We already have that spell, don't do anything
	if ((not override_same_spell or override_same_spell == 0) and
		current_spell == spell_index and
        spellbook.m_iSpellCharges > 0) then
		return;
	end

	-- We already have that amount of charges, don't do anything
	if ((not override_same_charges or override_same_charges == 0) and
		current_spell >= 0 and
		spell_index >= 0 and
		spellbook.m_iSpellCharges == charges) then
		return;
	end

    -- Reset any previous custom spell
    spellbook:ResetFakeSendProp("m_iSelectedSpellIndex");
    spellbook._m_iCustomSelectedSpellIndex = nil;

	-- No roll time or no charges
	if ( (not roll_time or roll_time <= 0) or (not charges or charges <= 0) ) then
        -- Custom spell
        if (spell_data[spell_index].is_custom) then
            spellbook.m_iSelectedSpellIndex        = SPELL_FIREBALL; -- Custom spells use fireball so we can detect projectile spawn
            spellbook._m_iCustomSelectedSpellIndex = spell_index;
            spellbook:SetFakeSendProp("m_iSelectedSpellIndex", spell_data[spell_index].fake_icon);
        -- Regular spell
        else
            spellbook.m_iSelectedSpellIndex = spell_index;
        end

		if (charges and charges > 0) then
			spellbook.m_iSpellCharges = charges;
		end

	-- Roll time and charges
	else
		spellbook.m_iSelectedSpellIndex = SPELL_CHOOSING -- Rolling...

        -- When we're done rolling...
		playerdata.spell_roll_timer = timer.Create(roll_time, function()
            if (not IsValid(player)) then return; end
            if (not IsValid(spellbook)) then
                spellbook = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
                if (not spellbook or spellbook.m_iClassname ~= "tf_weapon_spellbook") then goto cleanup; end
            end

            if (not player:IsWizard()) then
                spellbook.m_iSelectedSpellIndex = SPELL_NONE;
                goto cleanup;
            end

            -- Custom spell
            if (spell_data[spell_index].is_custom) then
                spellbook.m_iSelectedSpellIndex        = SPELL_FIREBALL; -- Custom spells use fireball so we can detect projectile spawn
                spellbook._m_iCustomSelectedSpellIndex = spell_index;
                spellbook:SetFakeSendProp("m_iSelectedSpellIndex", spell_data[spell_index].fake_icon);
            -- Regular spell
            else
                spellbook.m_iSelectedSpellIndex = spell_index;
            end

			spellbook.m_iSpellCharges = charges;

            ::cleanup::
            playerdata.spell_roll_timer = nil;
		end, 1);
	end
end

-- Give all RNG wizards a random spell of type spell_type
function GiveWizardsSpell(spell_type)
    for userid, playerdata in pairs(player_list) do
        local player = ents.GetPlayerByUserId(userid);

        if (player:IsWizard() and playerdata.wizard_type == WIZARD_USE_ROLLS) then
            if (spell_type == SPELL_TYPE_COMMON) then
                player:RollSpell(spell_rng_common_chances);
            elseif (spell_type == SPELL_TYPE_RARE) then
                player:RollSpell(spell_rng_rare_chances);
                player:PlaySoundToSelf("misc/halloween/merasmus_appear.wav");
            end
        end
    end
end

-- Give a player wizard items
function GivePlayerWizardItems(player, wizard_type)
    player:WeaponStripSlot(LOADOUT_POSITION_PRIMARY);
    player:WeaponStripSlot(LOADOUT_POSITION_SECONDARY);
    player:WeaponStripSlot(LOADOUT_POSITION_BUILDING);
    player:WeaponStripSlot(LOADOUT_POSITION_UTILITY);
    player:WeaponStripSlot(LOADOUT_POSITION_PDA);
    player:WeaponStripSlot(LOADOUT_POSITION_PDA2);

    player:WeaponSwitchSlot(LOADOUT_POSITION_MELEE);

    if (wizard_type == WIZARD_USE_MANA) then
		player:GiveItem("The Freedom Staff", {["killstreak tier"]=3, ["killstreak idleeffect"]=5});

    elseif (wizard_type == WIZARD_USE_ROLLS) then
        player.m_clrRender = math.rgbtoint(52, 116, 78);
    end

    player:GiveItem("TF_WEAPON_SPELLBOOK");
end