-- create a more generalized system for upgrades somehow

function UpgradeWizardUseMana(value, activator, caller)
    local userid = activator:GetUserId();
    if (not activator or not player_list[userid]) then return; end

    value = tonumber(value);

    if (value == UPGRADE_UPGRADE) then
        player_list[userid].wizard_type = WIZARD_USE_MANA;
        GivePlayerWizardItems(activator, player_list[userid].wizard_type);

        local melee = activator:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE);
        melee:SetAttributeValue("damage bonus", nil);
        melee:SetAttributeValue("damage penalty", 0.5);

    elseif (value == UPGRADE_DOWNGRADE) then
        player_list[userid].wizard_type = WIZARD_NONE;
        activator:ResetInventory();

    elseif (value == UPGRADE_RESTORE) then
        if (not activator:GetAttributeValue("zoom speed mod disabled") and
            not activator:GetAttributeValue("sniper no headshots")) then
            player_list[userid].wizard_type = WIZARD_NONE;
            activator:ResetInventory();
        end
    end
end

function UpgradeWizardUseRolls(value, activator, caller)
    local userid = activator:GetUserId();
    if (not activator or not player_list[userid]) then return; end

    value = tonumber(value);

    if (value == UPGRADE_UPGRADE) then
        player_list[userid].wizard_type = WIZARD_USE_ROLLS;
        GivePlayerWizardItems(activator, player_list[userid].wizard_type);

    elseif (value == UPGRADE_DOWNGRADE) then
        player_list[userid].wizard_type = WIZARD_NONE;
        activator:ResetInventory();

    elseif (value == UPGRADE_RESTORE) then
        if (not activator:GetAttributeValue("sniper no headshots") and
            not activator:GetAttributeValue("zoom speed mod disabled")) then
            player_list[userid].wizard_type = WIZARD_NONE;
            activator:ResetInventory();
        end
    end
end

function UpgradeWizardMaxMana(value, activator, caller)
    local userid = activator:GetUserId();
    if (not activator or not player_list[userid]) then return; end

    value = tonumber(value);
    local basemana = player_list[userid].base_mana;
    local maxmana  = player_list[userid].max_mana;
    local newmana  = maxmana

    if (value == UPGRADE_UPGRADE) then
        newmana = player_list[userid].max_mana + (math.round(basemana * 1.25) - basemana);

    elseif (value == UPGRADE_DOWNGRADE) then
        newmana = basemana;

    elseif (value == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue("tag__summer2014");
        if (not upgradeval) then
            newmana = basemana;
        elseif ((1 + upgradeval) * basemana ~= maxmana) then
            newmana = math.round((1 + upgradeval) * basemana);
        end
    end

    if (newmana < 0) then newmana = 0; end

    player_list[userid].max_mana     = newmana;
    player_list[userid].current_mana = newmana;
end

function UpgradeWizardManaRegen(value, activator, caller)
    local userid = activator:GetUserId();
    if (not activator or not player_list[userid]) then return; end

    value = tonumber(value);
    local baseregen = player_list[userid].base_mana_regen_rate;
    local newregen  = player_list[userid].mana_regen_rate;

    if (value == UPGRADE_UPGRADE) then
        newregen = player_list[userid].mana_regen_rate + 5;

    elseif (value == UPGRADE_DOWNGRADE) then
        newregen = baseregen;

    elseif (value == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue("elevate to unusual if applicable");
        if (not upgradeval) then
            newregen = baseregen;
        elseif (baseregen + upgradeval ~= newregen) then
            newregen = math.round(baseregen + upgradeval);
        end
    end

    if (newregen < 0) then newregen = 0; end

    player_list[userid].mana_regen_rate = newregen;
end

function HandleUpgradeUnlock(upgradetype, activator, spell, attribute)
    if (not activator or not player_list[activator:GetUserId()]) then return; end
    local userid = activator:GetUserId();

    local playerspelldata = player_list[userid].upgrades_spell_data;
    upgradetype = tonumber(upgradetype);

    local newval = playerspelldata[spell];

    if (upgradetype == UPGRADE_UPGRADE) then
        newval = {_id=activator:CountUnlockedSpells()+1}

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
        newval = {};

    elseif (upgradetype == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue(attribute);
        if (not upgradeval) then
            newval = {};
        end
    end

    playerspelldata[spell] = newval;
end

function HandleUpgradeValue(upgradetype, activator, modvalue, spelltype, attribute, data)
    if (not activator or not player_list[activator:GetUserId()]) then return; end
    local userid = activator:GetUserId();

    local playerspelltypedata = player_list[userid].upgrades_spelltype_data;
    upgradetype = tonumber(upgradetype);

    local newval = playerspelltypedata[spelltype][data];

    if (upgradetype == UPGRADE_UPGRADE) then
        newval = newval - (1 - 1 * modvalue);

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
        newval = 1;

    elseif (upgradetype == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue(attribute)
        if (not upgradeval) then
            newval = 1;
        elseif (1 * upgradeval ~= newval) then
            newval = math.round(1 * newval);
        end
    end

    playerspelltypedata[spelltype][data] = newval;

    return true;
end


function UpgradeSpellbookCommonsManaCost(value, activator, caller)
    HandleUpgradeValue(value, activator, 0.9, SPELL_TYPE_COMMON, "custom texture lo", "mana_cost");
end

function UpgradeSpellbookCommonsRollTime(value, activator, caller)
    HandleUpgradeValue(value, activator, 0.9, SPELL_TYPE_COMMON, "cannot trade", "roll_time");
end

function UpgradeSpellbookRaresManaCost(value, activator, caller)
    HandleUpgradeValue(value, activator, 0.9, SPELL_TYPE_RARE, "duel loser account id", "mana_cost");
end

function UpgradeSpellbookRaresRollTime(value, activator, caller)
    HandleUpgradeValue(value, activator, 0.9, SPELL_TYPE_RARE, "event date", "roll_time");
end

function UpgradeSpellbookUnlockFireball(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_FIREBALL, "DEPRECATED socketed item definition id DEPRECATED ");
end

function UpgradeSpellbookUnlockBallobats(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_BALLOBATS, "purchased");
end

function UpgradeSpellbookUnlockHealingaura(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_HEALINGAURA, "gifter account id");
end

function UpgradeSpellbookUnlockPumpkinmirv(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_PUMPKINMIRV, "referenced item id high");
end

function UpgradeSpellbookUnlockSuperjump(value, activator, caller)
    if (not activator or not player_list[activator:GetUserId()]) then return; end

    HandleUpgradeUnlock(value, activator, SPELL_SUPERJUMP, "halloween item");

    local upgradetype = tonumber(value);

    if (upgradetype == UPGRADE_UPGRADE) then
        activator:SetAttributeValue("cancel falling damage", 1);

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
        activator:SetAttributeValue("cancel falling damage", 0);

    elseif (upgradetype == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue("halloween item");
        if (not upgradeval) then
            activator:SetAttributeValue("cancel falling damage", 0);
        end
    end
end

function UpgradeSpellbookUnlockInvisibility(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_INVISIBILITY, "force level display");
end

function UpgradeSpellbookUnlockTeleport(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_TELEPORT, "unique craft index");
end

function UpgradeSpellbookUnlockTeslabolt(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_TESLABOLT, "unlimited quantity");
end

function UpgradeSpellbookUnlockMinify(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_MINIFY, "strange part new counter ID");
end

function UpgradeSpellbookUnlockMeteorshower(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_METEORSHOWER, "pyro year number");
end

function UpgradeSpellbookUnlockSummonmonoculus(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_SUMMONMONOCULUS, "zombiezombiezombiezombie");
end

function UpgradeSpellbookUnlockSummonmonskeletons(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_SUMMONSKELETONS, "strange restriction type 2");
end

function UpgradeSpellbookUnlockCrocket(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_CUSTOM_CROCKET, "sniper no charge");
end

function UpgradeSpellbookUnlockGravitybomb(value, activator, caller)
    HandleUpgradeUnlock(value, activator, SPELL_CUSTOM_GRAVITYBOMB, "strange restriction user value 1");
end

function UpgradePyroAOEBlast(value, activator, caller)
    if (not activator or not player_list[activator:GetUserId()]) then return; end

    local upgradetype = tonumber(value);
    local userid = activator:GetUserId();
    local chargetime = player_list[userid].pyro_aoeblast_chargetime;

    if (upgradetype == UPGRADE_UPGRADE) then
        player_list[userid].pyro_aoeblast_chargetime = chargetime - 5;

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
        player_list[userid].pyro_aoeblast_chargetime = player_list[userid].pyro_aoeblast_base_chargetime;

    elseif (upgradetype == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue("ring of fire while aiming");
        if (not upgradeval) then
            player_list[userid].pyro_aoeblast_chargetime = player_list[userid].pyro_aoeblast_base_chargetime;
        end
    end
end

function UpgradePyroAOEBlastDuration(value, activator, caller)
    local userid = activator:GetUserId();
    if (not activator or not player_list[userid]) then return; end

    value = tonumber(value);
    local newval = player_list[userid].pyro_aoeblast_duration;

    if (value == UPGRADE_UPGRADE) then
        newval = newval + 1;

    elseif (value == UPGRADE_DOWNGRADE) then
        newval = 0;

    elseif (value == UPGRADE_RESTORE) then
        local upgradeval = activator:GetAttributeValue("strange restriction value 2");
        if (not upgradeval) then
            newval = 0;
        elseif (0 + upgradeval ~= newval) then
            newval = math.round(0 + newval);
        end
    end

    player_list[userid].pyro_aoeblast_duration = newval;
end

function UpgradeDemoHatchetRechargeTime(value, activator, caller)
    if (not activator or not player_list[activator:GetUserId()]) then return; end

    local upgradetype = tonumber(value);
    local userid = activator:GetUserId();
    local chargetime = player_list[userid].demo_hatchet_chargetime;

    if (upgradetype == UPGRADE_UPGRADE) then
        player_list[userid].demo_hatchet_chargetime = chargetime - 0.5;

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
        player_list[userid].demo_hatchet_chargetime = player_list[userid].demo_hatchet_base_chargetime;

    elseif (upgradetype == UPGRADE_RESTORE) then
		local wep = activator:GetPlayerItemBySlot(LOADOUT_POSITION_MELEE);
		if (IsValid(wep)) then
			local upgradeval = wep:GetAttributeValue("strange restriction user value 3");
			if (not upgradeval) then
				player_list[userid].demo_hatchet_chargetime = player_list[userid].demo_hatchet_base_chargetime;
			end
		end
    end
end

function HandleFlaskUnlock(value, activator, flask, attr)
    if (not activator or not player_list[activator:GetUserId()]) then return; end

    local upgradetype = tonumber(value);
    local userid = activator:GetUserId();

    if (upgradetype == UPGRADE_UPGRADE) then
        table.insert(player_list[userid].medic_flask_data, flask);

    elseif (upgradetype == UPGRADE_DOWNGRADE) then
		local newtable = {};
        for index, flasktype in pairs(player_list[userid].medic_flask_data) do
			if (flasktype ~= flask) then
				newtable[index] = flasktype;
			end
		end
		player_list[userid].medic_flask_data = newtable;
		
    elseif (upgradetype == UPGRADE_RESTORE) then
		local wep = activator:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
		if (IsValid(wep)) then
			local upgradeval = wep:GetAttributeValue(attr);
			if (not upgradeval) then
				local newtable = {};
				for index, flasktype in pairs(player_list[userid].medic_flask_data) do
					if (flasktype ~= flask) then
						newtable[index] = flasktype;
					end
				end
				player_list[userid].medic_flask_data = newtable;
			end
		end
    end
end

function UpgradeMedicFlaskBleeding(value, activator, caller)
	HandleFlaskUnlock(value, activator, FLASK_BLEED, "squad surplus claimer id DEPRECATED");
end
function UpgradeMedicFlaskHealDebuff(value, activator, caller)
	HandleFlaskUnlock(value, activator, FLASK_HEAL_DEBUFF, "accepted wedding ring account id 1");
end
function UpgradeMedicFlaskLongHeal(value, activator, caller)
	HandleFlaskUnlock(value, activator, FLASK_LONGHEAL, "tool escrow until date");
end
function UpgradeMedicFlaskQuickHeal(value, activator, caller)
	HandleFlaskUnlock(value, activator, FLASK_QUICKHEAL, "mvm completed challenges bitmask");
end
function UpgradeMedicFlaskUber(value, activator, caller)
	HandleFlaskUnlock(value, activator, FLASK_UBER, "explosive sniper shot");
end