-- Not limited by midwave restrictions
-- Pick any spell regardless of upgrade unlocks
debug = true;

precache.PrecacheModel("models/capnkinky.mdl", true);
precache.PrecacheModel("models/workshop/weapons/c_models/c_celtic_cleaver/c_demo_sultan_sword.mdl", true);

precache.PrecacheScriptSound("Halloween.spell_lightning_cast");
precache.PrecacheScriptSound("Halloween.spell_overheal");
precache.PrecacheScriptSound("Halloween.spell_blastjump");
precache.PrecacheScriptSound("Halloween.spell_stealth");
precache.PrecacheScriptSound("Weapon_RPG.SingleCrit");
precache.PrecacheScriptSound("BaseExplosionEffect.Sound");
precache.PrecacheScriptSound("Weapon_Mantreads.Impact");
precache.PrecacheScriptSound("Player.FallDamageDealt");

precache.PrecacheSound("ambient/fireball.wav");
precache.PrecacheSound("ambient/medieval_falcon.wav");
precache.PrecacheSound("player/recharged.wav");
precache.PrecacheSound("misc/halloween/merasmus_appear.wav");
precache.PrecacheSound("ambient/energy/zap1.wav");
precache.PrecacheSound("vo/taunts/demo/taunt_demo_dose_fun_08.mp3");
precache.PrecacheSound("vo/demoman_mvm_resurrect02.mp3");
precache.PrecacheSound("vo/demoman_mvm_resurrect08.mp3");
precache.PrecacheSound("vo/demoman_mvm_resurrect09.mp3");
precache.PrecacheSound("player/invulnerable_on.wav");
precache.PrecacheSound("weapons/medigun_heal.wav");
precache.PrecacheSound("weapons/buffed_on.wav");
precache.PrecacheSound("misc/halloween/spell_pickup_rare.wav");

for i=1,3 do precache.PrecacheSound("weapons/demo_charge_hit_flesh"..i..".wav"); end
for i=1,4 do precache.PrecacheSound("ambient/energy/spark"..i..".wav"); end
for i=1,3 do precache.PrecacheSound("weapons/samurai/tf_katana_impact_object_0"..i..".wav"); end
for i=1,3 do precache.PrecacheSound("weapons/demo_sword_swing"..i..".wav"); end

precache.PrecacheParticle("heavy_ring_of_fire");
precache.PrecacheParticle("mvm_hatch_destroy_smolderembers");
precache.PrecacheParticle("flaregun_energyfield_red");
precache.PrecacheParticle("dxhr_lightningball_glow3_red");
precache.PrecacheParticle("stomp_text");
precache.PrecacheParticle("rd_robot_explosion_smoke_linger");
precache.PrecacheParticle("utaunt_lightning_bolt");
precache.PrecacheParticle("utaunt_marigoldritual_blue_orbit_holder");

demo_sober_sounds = {
	"vo/taunts/demo/taunt_demo_dose_fun_08.mp3",
	"vo/demoman_mvm_resurrect02.mp3",
	"vo/demoman_mvm_resurrect08.mp3",
	"vo/demoman_mvm_resurrect09.mp3"
};

-- m_iAmmo
TF_AMMO_DUMMY     = 1;
TF_AMMO_PRIMARY   = 2;
TF_AMMO_SECONDARY = 3;
TF_AMMO_METAL     = 4;
TF_AMMO_GRENADES1 = 5;
TF_AMMO_GRENADES2 = 6;
TF_AMMO_GRENADES3 = 7;
TF_AMMO_COUNT     = 8;

player_list = {};
midwave     = false;
tickrate    = 66;

common_spell_time = 5;
rare_spell_time   = 30;

common_timer_value = common_spell_time;
rare_timer_value   = rare_spell_time;

wizard_rng_rolls_custom_spells = true;

WIZARD_NONE      = 0;
WIZARD_USE_MANA  = 1;
WIZARD_USE_ROLLS = 2;

SPELL_TYPE_NONE   = 0;
SPELL_TYPE_COMMON = 1;
SPELL_TYPE_RARE   = 2;

SPELL_CHOOSING         = -2;
SPELL_NONE             = -1;
SPELL_FIREBALL         =  0;
SPELL_BALLOBATS        =  1;
SPELL_HEALINGAURA      =  2;
SPELL_PUMPKINMIRV      =  3;
SPELL_SUPERJUMP        =  4;
SPELL_INVISIBILITY     =  5;
SPELL_TELEPORT         =  6;
SPELL_TESLABOLT        =  7;
SPELL_MINIFY           =  8;
SPELL_METEORSHOWER     =  9;
SPELL_SUMMONMONOCULUS  =  10;
SPELL_SUMMONSKELETONS  =  11;
SPELL_KARTBOXINGROCKET =  12;
SPELL_KARTBASEJUMP     =  13;
SPELL_KARTOVERHEAL     =  14;
SPELL_KARTBOMBHEAD     =  15;

SPELL_CUSTOM_CROCKET     = 16;
SPELL_CUSTOM_GRAVITYBOMB = 17;

spell_rng_common_chances = {
	[SPELL_FIREBALL]       = { roll_chance=0.5,  charge_chances = {0.2, 0.7, 0.07, 0.03} },
	[SPELL_HEALINGAURA]    = { roll_chance=0.2,  charge_chances = {0.4, 0.5, 0.1,      } },
	[SPELL_PUMPKINMIRV]    = { roll_chance=0.15, charge_chances = {0.7, 0.2, 0.1,      } },
	[SPELL_CUSTOM_CROCKET] = { roll_chance=0.15, charge_chances = {0.7, 0.2, 0.1,      } },
};

spell_rng_rare_chances = {
	[SPELL_SUMMONSKELETONS]    = { roll_chance=0.5,  charge_chances = {0.9, 0.1,} },
	[SPELL_SUMMONMONOCULUS]    = { roll_chance=0.3,  charge_chances = {0.9, 0.1,} },
	[SPELL_METEORSHOWER]       = { roll_chance=0.10, charge_chances = {1        } },
	[SPELL_TESLABOLT]          = { roll_chance=0.05, charge_chances = {1        } },
	[SPELL_CUSTOM_GRAVITYBOMB] = { roll_chance=0.05, charge_chances = {1        } },
};


spell_projectile_class_map = {
	tf_projectile_spellfireball          = SPELL_FIREBALL,
	tf_projectile_spellbats              = SPELL_BALLOBATS,
	tf_projectile_spellmirv              = SPELL_PUMPKINMIRV,
	tf_projectile_spelltransposeteleport = SPELL_TELEPORT,
	tf_projectile_lightningorb           = SPELL_TESLABOLT,
	tf_projectile_spellmeteorshower      = SPELL_METEORSHOWER,
	tf_projectile_spellspawnboss         = SPELL_SUMMONMONOCULUS,
	tf_projectile_spellspawnhorde        = SPELL_SUMMONSKELETONS,
	tf_projectile_spellkartorb           = SPELL_KARTBOXINGROCKET,
};

FLASK_NONE        = 0;
FLASK_BLEED       = 1;
FLASK_HEAL_DEBUFF = 2;
FLASK_QUICKHEAL   = 3;
FLASK_UBER        = 4;

flask_name_map = {
	[FLASK_NONE]        = "None",
	[FLASK_BLEED]       = "Bleeding [Enemies]",
	[FLASK_HEAL_DEBUFF] = "Healing Debuff [Enemies]",
	[FLASK_QUICKHEAL]   = "Quick Heal [Allies]",
	[FLASK_UBER]        = "Übercharge [Allies]",
};

CLR_WHITE     = {250, 245, 240};
CLR_RED       = {250, 50, 0};
CLR_ORANGE    = {250, 100, 50};
CLR_LIMEGREEN = {100, 250, 50};
CLR_BLUE      = {50, 100, 250};
CLR_PURPLE    = {150, 50, 175};
CLR_MAGENTA   = {250, 50, 150};

UPGRADE_UPGRADE   = 0;
UPGRADE_APPLY     = 1;
UPGRADE_DOWNGRADE = 2;
UPGRADE_RESTORE   = 3;

VALUE_INTEGER = 0;
VALUE_FLOAT   = 1;

dungeon_entities = {};

kinky_props_disabled = false;
kinky_filter         = nil;
kinky_respawn_text   = nil;
kinky_respawn_text2  = nil;

kinky_mindmg = 0.6154; -- 40 dmg
kinky_maxdmg = 1.9231; -- 125 dmg
kinky_maxdmgatcurrency = 4500;

-- Lua isn't able to spawn point_worldtext for some reason
VSCRIPT_RESPAWN_TEXT = [[
SpawnEntityFromTable("point_worldtext", {
	targetname  = "kinky_respawn_text",
	origin      = "-4674 -5920 -1940",
	color       = "255 255 255",
	textsize    = 18,
	orientation = 2,
});

SpawnEntityFromTable("point_worldtext", {
	targetname  = "kinky_respawn_text2",
	origin      = "-4674 -5920 -1965",
	color       = "30 210 60",
	textsize    = 18,
	orientation = 2,
});
]];

item_whitelist_enabled = true;
function DisableItemWhitelist() item_whitelist_enabled = false; end
function EnableItemWhitelist()  item_whitelist_enabled = true; end
function ToggleItemWhitelist()  item_whitelist_enabled = not item_whitelist_enabled; end

item_whitelist = {
	"tf_wearable",
	"saxxy",
	"tf_weapon_spellbook",
	
	"tf_weapon_lunchbox_drink",
	"tf_weapon_jar_milk",
	"tf_weapon_cleaver",
	"tf_weapon_bat",
	"tf_weapon_bat_wood",
	"tf_weapon_bat_fish",
	"tf_weapon_bat_giftwrap",
	
	"tf_weapon_buff_item",
	"The B.A.S.E. Jumper",
	"tf_weapon_shovel",
	"tf_weapon_katana",
	
	"The Thermal Thruster",
	"tf_weapon_fireaxe",
	"tf_weapon_breakable_sign",
	"tf_weapon_slap",
	
	"The Loose Cannon",
	"tf_wearable_demoshield",
	"tf_weapon_bottle",
	"tf_weapon_sword",
	"tf_weapon_stickbomb",
	
	"tf_weapon_lunchbox",
	"tf_weapon_fists",
	
	"tf_weapon_wrench",
	"tf_weapon_robot_arm",
	
	"tf_weapon_crossbow",
	"tf_weapon_syringegun_medic",
	"tf_weapon_bonesaw",
	
	"tf_weapon_compound_bow",
	"tf_wearable_razorback",
	"tf_weapon_jar",
	"tf_weapon_club",
	
	"tf_weapon_knife",
	"tf_weapon_pda_spy",
	"tf_weapon_invis",
};

TAG_ITEMNAME  = "hp_itemname";

TAG_ITEMPOS   = "hp_itempos";
TAG_ITEMANG   = "hp_itemang";
TAG_ITEMSCALE = "hp_itemscale";

TAG_COSMETICS = "hp_cosmetics";

TAG_LOADOUT_SLOT_MAP = {
	hp_loadout_primary = 0,
	hp_loadout_secondary = 1,
	hp_loadout_melee = 2,
};

TAG_LOADOUT_START     = "hp_loadout_"
TAG_LOADOUT_PRIMARY   = "hp_loadout_primary";
TAG_LOADOUT_SECONDARY = "hp_loadout_secondary";
TAG_LOADOUT_MELEE     = "hp_loadout_melee";

TAG_IGNORECLASS         = "hp_ignoreclass";

