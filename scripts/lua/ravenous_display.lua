function OnMenuCancel(player, reason)
	player_list[player:GetUserId()].displaying_menu = nil;
end

function OnSpellMenuSelect(player, selectedIndex, value)
	local userid = player:GetUserId()
	value = tonumber(value);

	if (not player:IsWizard()) then return; end

	player_list[userid].displaying_menu = nil;

	if (not debug and not midwave) then
		player:Print(PRINT_TARGET_CENTER, "You can only select spells once the wave starts!");
		return;
	end

	local spellbook = player:GetPlayerItemBySlot(LOADOUT_POSITION_ACTION);
	if (not spellbook or spellbook.m_iClassname ~= "tf_weapon_spellbook") then return; end

	-- We add a small delay to prevent frame perfect spell cast then spell switch which avoids
	-- paying mana for the spell just cast (SPELL_CHOOSING has a mana cost of 0)
	timer.Create(0.25, function()
		SelectSpell(spellbook, value, GetSpellData(player, nil, value, "charges", true),
					GetSpellData(player, nil, value, "roll_time", false), false, true);
	end, 1);
end

function OnFlaskMenuSelect(player, selectedIndex, value)
	local userid = player:GetUserId()
	value = tonumber(value);
	
	local playerdata = player_list[userid];
	
	playerdata.displaying_menu     = nil;
	playerdata.medic_current_flask = value;
	
	local wep = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
	if (not IsValid(wep) or wep:GetAttributeValue("store sort override DEPRECATED") ~= 1) then return; end
	
	if (CurTime() >= wep.m_flEffectBarRegenTime) then
		-- Get a new random flask liquid color
		player:RemoveItem("Flask");
		player:GiveItem("Flask");
		
		player:PlaySoundToSelf("player/recharged.wav");
		player:WeaponSwitchSlot(LOADOUT_POSITION_SECONDARY);
	end
end

base_spell_menu = {
	timeout      = 0,
	title        = "Choose a Spell!",
	itemsPerPage = nil,
	flags        = MENUFLAG_BUTTON_EXIT,
	onSelect     = OnSpellMenuSelect,
	onCancel     = OnMenuCancel,
};

debug_spell_menu = {
	timeout      = 0,
	title        = "[DEBUG] Choose a Spell",
	itemsPerPage = nil,
	flags        = MENUFLAG_BUTTON_EXIT,
	onSelect     = OnSpellMenuSelect,
	onCancel     = OnMenuCancel,
};
-- Populate debug menu with all spells
for spell, data in pairs(spell_data) do
	debug_spell_menu[spell+1] = {text=data.name, value=spell, disabled=false};
end

base_flask_menu = {
	timeout      = 0,
	title        = "Choose a Flask!",
	itemsPerPage = nil,
	flags        = MENUFLAG_BUTTON_EXIT,
	onSelect     = OnFlaskMenuSelect,
	onCancel     = OnMenuCancel,
};

-- Create a menu for a player based on their spell upgrade unlocks
function CreateSpellMenuForPlayer(player)
	if (not IsValidRealPlayer(player)) then return; end

	local userid   = player:GetUserId();
	local new_menu = {};

	-- Inherit from base spell menu
	for key, val in pairs(base_spell_menu) do
		new_menu[key] = val;
	end

	-- Populate with player's unlocked spells
	for spell, playerspelldata in pairs(player_list[userid].upgrades_spell_data) do
		if (playerspelldata._id and playerspelldata.name) then
			new_menu[playerspelldata._id] = {text=playerspelldata.name, value=spell, disabled=false};
		elseif (playerspelldata._id) then
			new_menu[playerspelldata._id] = {text=spell_data[spell].name, value=spell, disabled=false};
		end
	end

	return new_menu;
end

function CreateFlaskMenuForPlayer(player)
	if (not IsValidRealPlayer(player)) then return; end
	
	local userid   = player:GetUserId();
	local new_menu = {};
	
	-- Inherit from base spell menu
	for key, val in pairs(base_flask_menu) do
		new_menu[key] = val;
	end
	
	local playerdata = player_list[userid];
	for index, flasktype in pairs(playerdata.medic_flask_data) do
		new_menu[index] = {text=flask_name_map[flasktype], value=flasktype, disabled=false};
	end

	return new_menu;
end

-- Clear the player's screen of hud text
function DisplayClearHud(player)
	for i=2,5 do
		player:ShowHudTextSimple("", i, 0, 0, CLR_WHITE, 0, 0, 0.015);
	end
end

function DisplayManaWizardHud(player, spellbook, playerdata, current_mana_cost)
	-- Get our the spellbook's current spell
	local current_spell = spell_data[spellbook.m_iSelectedSpellIndex].name;
	if (spellbook._m_iCustomSelectedSpellIndex) then
		current_spell = spell_data[spellbook._m_iCustomSelectedSpellIndex].name;
	end

	if (playerdata.current_mana - current_mana_cost >= 0) then
		player:ShowHudTextSimple("Mana: "..playerdata.current_mana.." [+"..playerdata.mana_regen_rate.."/s]", 3, .78, .75, CLR_BLUE);
	else
		player:ShowHudTextSimple("Mana: "..playerdata.current_mana.." [+"..playerdata.mana_regen_rate.."/s]", 3, .78, .75, CLR_RED);
	end

	player:ShowHudTextSimple("Cost:  "..current_mana_cost, 4, .78, .8, CLR_RED);
	player:ShowHudTextSimple("Press 'Reload' to select a spell!", 5, .8, .85, CLR_LIMEGREEN);
end

function DisplayRollsWizardHud(player, spellbook)
	-- Get our the spellbook's current spell name
	local current_spell = spell_data[spellbook.m_iSelectedSpellIndex].name;
	if (spellbook._m_iCustomSelectedSpellIndex) then
		current_spell = spell_data[spellbook._m_iCustomSelectedSpellIndex].name;
	end
	if (spellbook.m_iSpellCharges == 0 and current_spell ~= spell_data[SPELL_CHOOSING].name) then
		current_spell = "None";
	end

	player:ShowHudTextSimple("Spell:  "..current_spell, 3, .78, .7, CLR_WHITE);
	player:ShowHudTextSimple("Next Common: "..common_timer_value, 4, .78, .75, CLR_PURPLE);
	player:ShowHudTextSimple("Next Rare:       "..rare_timer_value, 5, .78, .8, CLR_ORANGE);
end

function DisplaySoldierHud(player)
	player:ShowHudTextSimple("Press 'Mouse2' to blast jump!", 5, .77, .85, CLR_LIMEGREEN, 0, .25, 3);
end

function DisplayPyroHud(player, label, chargetime, damagebonus_label)
	player:ShowHudTextSimple("AOE Fireblast: "..label.." ["..chargetime.."s]", 3, .77, .8, CLR_ORANGE);
	player:ShowHudTextSimple("Damage Bonus: "..damagebonus_label, 4, .77, .85, CLR_RED);
	player:ShowHudTextSimple("Press 'Reload' to activate!", 5, .77, .9, CLR_LIMEGREEN);
end

function DisplayDemoHud(player, wep)
	local label = "";
	if (IsValid(wep)) then
		-- Hatchet
		if (wep:GetAttributeValue("back headshot") == 1) then
			label = "Press 'Reload' to throw!";
		else
			-- No parrying with a shield
			local secondary = player:GetPlayerItemBySlot(LOADOUT_POSITION_SECONDARY);
			if (not IsValid(secondary) or secondary.m_iClassname ~= "tf_wearable_demoshield") then
				-- Persian Persuader
				if (wep.m_iItemDefinitionIndex == 404 or
					wep.m_iClassname == "tf_weapon_sword" or wep.m_iClassname == "tf_weapon_katana") then

					label = "Press 'Mouse2' to parry melee attacks!";
				end			
			end
		end
	end
	player:ShowHudTextSimple(label, 5, .77, .85, CLR_LIMEGREEN, 0, .25, 3);
end

function DisplayDemoScrumpyHud(player, label, chargetime)
	player:ShowHudTextSimple("Scrumpy: "..label.." ["..chargetime.."s]", 4, .77, .8, CLR_MAGENTA);
	player:ShowHudTextSimple("Drink booze to activate!", 5, .77, .85, CLR_LIMEGREEN);
end

function DisplayMedicHud(player, current_flask)
	player:ShowHudTextSimple("Name:  "..current_flask, 4, .8, .8, CLR_RED);
	player:ShowHudTextSimple("Press 'Reload' to select a flask!", 5, .8, .85, CLR_LIMEGREEN);
end

function DisplayCivilianHud(player, label, chargetime, superdash_label, superdashchargetime)
	player:ShowHudTextSimple("Rage: "..label.." ["..chargetime.."s]", 2, .77, .66, CLR_ORANGE);
	player:ShowHudTextSimple("Press 'Reload' to activate!", 3, .77, .71, CLR_LIMEGREEN);
	player:ShowHudTextSimple("Super Dash: "..superdash_label.." ["..superdashchargetime.."s]", 4, .77, .79, CLR_MAGENTA);
	player:ShowHudTextSimple("Hold and release 'Mouse2' to activate!", 5, .77, .84, CLR_LIMEGREEN);
end
