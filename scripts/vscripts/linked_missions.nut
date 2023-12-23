WHITESPACE <- [9, 10, 11, 12, 13, 32];

function ParseSaveFileString(str)
{
	local table = {};
	if (!str || str == "") return table;
	
	local start  = null;
	local in_str = false;
	local key    = null;
	local val    = null;
	for (local i = 0; i < str.len(); ++i)
	{
		local ch = str[i];

		if (WHITESPACE.find(ch) != null)
		{
			if (start != null)
			{
				if (in_str) continue;
				
				// End of token
				local token  = str.slice(start, i);
				
				if (key != null) val = token;
				else key = token;
				
				start = null;
			}
		}
		else
		{
			if (start == null)
			{
				start = i;
				
				if (ch == 34) // (") quote char
				{
					in_str = true;
				}
			}
			else
			{
				// End of string
				if (ch == 34) // (") quote char
				{
					in_str = false;
					
					local token  = str.slice(start, i+1);
					
					if (key != null) val = token;
					else key = token;
					
					start = null;
				}
			}
		}
		
		// Add slot and reset
		if (key != null && val != null)
		{
			table[key] <- val;
			
			start = null;
			key   = null;
			val   = null;
		}
		
		// Ensure the last slot at EOF is added
		if (i == str.len() - 1 && key != null && start != null)
		{
			table[key] <- str.slice(start);
			break;
		}
	}
	
	return table;
}

function WriteObjectToSaveFile(file, obj)
{
	local str = "";
	foreach (key, val in obj)
		str += key + " " + val + "\n";
		
	StringToFile(file, str);
}

function TableHasKey(table, key)
{
	foreach (k, v in table)
		if (k == key) return true;
		
	return false;
}

function SplitMissionString(str)
{
	if (str.find("\"") == 0)
		str = str.slice(1, -1);
	
	local map     = null;
	local mission = null;
	
	local difficulty_index = null;
	local difficulty = "";
	foreach (diff in ["_int_", "_adv_", "_exp_"])
	{
		difficulty_index = str.find(diff);
		difficulty = diff;
		
		if (difficulty_index != null)
			break;
	}
		
	if (difficulty_index != null)
	{
		map        = str.slice(0, difficulty_index);
		mission    = str.slice(difficulty_index+difficulty.len(), -4);
		difficulty = difficulty.slice(1, -1);
	}
	
	return {map=map, mission=mission, difficulty=difficulty};
}

SAVE_FILE_NAME <- "_campaign_lastmissions.log";

CAMPAIGN_LIST <- {
	Ravenous = [
		"mvm_winterbridge_rc6_adv_ravenous.pop",
		"mvm_frostwynd_rc1_adv_ravenous.pop",
		"mvm_chateau_rc3_adv_ravenous.pop",
	],
};

// Format
foreach (campaign, missionlist in CAMPAIGN_LIST)
{
	foreach (index, mission in missionlist)
	{
		missionlist[index] = "\"" + mission + "\"";
	}
}

local tf_objective_resource = Entities.FindByClassname(null, "tf_objective_resource");
local tf_gamerules          = Entities.FindByClassname(null, "tf_gamerules");


// Create save file if necessary
local save_file = FileToString(SAVE_FILE_NAME);
local save_file_object = null;
if (!save_file)
	StringToFile(SAVE_FILE_NAME, "");
	
// Get mission info
local currentmission = NetProps.GetPropString(tf_objective_resource, "m_iszMvMPopfileName");
currentmission = "\"" + currentmission.slice(currentmission.find("mvm")) + "\"";

// Get hostname
local hostname = "\"" + Convars.GetStr("hostname") + "\"";


// Let's rock and roll boys
local campaign_mission = false;
if (currentmission != null && currentmission != "" && hostname != null && hostname != "")
{
	save_file_object     = ParseSaveFileString(save_file);
	local changing_level = false;
	
	// Is this mission part of a campaign?
	local breaking = false;
	foreach (campaign_name, mission_list in CAMPAIGN_LIST)
	{
		foreach (index, mission in mission_list)
		{
			if (currentmission == mission)
			{
				campaign_mission = true;
				
				// The current mission is partway through a campaign
				if (index > 0)
				{
					// Check save file to ensure we played the previous mission
					if (!TableHasKey(save_file_object, hostname) ||
						(save_file_object[hostname] != mission_list[index-1] && save_file_object[hostname] != currentmission))
					{
						// Go back to first mission in campaign
						changing_level = true;
						
						// Seperate map and mission from mission string
						local info = SplitMissionString(mission_list[0]);
						
						local str = info["map"] + "|" + info["difficulty"] + "_" + info["mission"];
						EntFireByHandle(tf_gamerules, "$ChangeLevel", str, -1, null, null);
					}
				}
				
				if (TableHasKey(save_file_object, hostname))
				{
					delete save_file_object[hostname];
					WriteObjectToSaveFile(SAVE_FILE_NAME, save_file_object);
				}
				
				breaking = true;
				break;
			}
		}
		
		if (breaking)
			break;
	}
	
	// Non-campaign missions write to savefile on mission load indiscriminately 
	if (!changing_level && !campaign_mission)
	{
		if (TableHasKey(save_file_object, hostname))
		{
			delete save_file_object[hostname];
			WriteObjectToSaveFile(SAVE_FILE_NAME, save_file_object);
		}
	}
}

// Called in popfile on last wave completion
function SaveCurrentMission()
{
	save_file_object[hostname] <- currentmission;
	WriteObjectToSaveFile(SAVE_FILE_NAME, save_file_object);
}