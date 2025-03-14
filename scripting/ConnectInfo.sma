#include <amxmodx>
#include <grip>

const TASK_CHAT = 3243;

new g_iApiKey[64];

new g_iHours[32];

public plugin_init() {
	register_plugin("Connect player info", "0.0.1", "OpenHNS");

	bind_pcvar_string(create_cvar("ci_api_key", "", FCVAR_NONE, "API key steam^nhttps://steamcommunity.com/dev/apikey"), g_iApiKey, charsmax(g_iApiKey));

	AutoExecConfig(true, "connect_info");
}

public client_putinserver(id) {
	new szAuth[24], szSteamID64[64]; 

	get_user_authid(id, szAuth, charsmax(szAuth));
	steamid_get_steamid64(szAuth, szSteamID64, charsmax(szSteamID64));

	new szRequest[256];
	formatex(szRequest, charsmax(szRequest), "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001?key=%s&steamid=%s&appids_filter[0]=10&format=json", g_iApiKey, szSteamID64);
	
	grip_request(szRequest, Empty_GripBody, GripRequestTypeGet, "HandleRequest", .userData = id);
}

public HandleRequest(const id) {
	if(!is_user_connected(id)) {
		return;
	}
	
	new szAuth[24]; 
	get_user_authid(id, szAuth, charsmax(szAuth));

	new GripResponseState:responseState = grip_get_response_state();

	if(responseState == GripResponseStateError)
		return;

	new GripHTTPStatus:status = grip_get_response_status_code();

	if(status != GripHTTPStatusOk) {
		log_amx("Error: %d", status);
		if(status == GripHTTPStatusForbidden) {
			log_amx("Invalid API Key");
		} else if(status == GripHTTPStatusInternalServerError) {
			new szSteamID64[64];
			steamid_get_steamid64(szAuth, szSteamID64, charsmax(szSteamID64));
			log_amx("Invalid SteamID64 (%s | %s)", szAuth, szSteamID64);
		}

		return;
	}

	new szError[128];

	new GripJSONValue:data = grip_json_parse_response_body(szError, charsmax(szError));

	if(data == Invalid_GripJSONValue) {
		log_amx("Error: %s", szError);
		return;
	}

	new iResponse[32];
	
	iResponse[id] = grip_json_object_get_number(grip_json_array_get_value(grip_json_object_get_value(grip_json_object_get_value(data, "response"), "games"), 0), "playtime_forever");
	
	g_iHours[id] = iResponse[id] / 60;
	
	grip_destroy_json_value(data);

	set_task(1.0, "chat_info", TASK_CHAT + id);
}

public chat_info(idtask) {
	new id = idtask - TASK_CHAT;

	client_print_color(0, print_team_blue, "^3%n^1 has connected. (^3%d^1 h.)", id, g_iHours[id]);
}

steamid_get_steamid64(const steamid[], buffer[], const len) {
	new steamid_exploded[3][11]
	explode_string(steamid, ":", steamid_exploded, sizeof(steamid_exploded), sizeof(steamid_exploded[]))
	new carry = str_to_num(steamid_exploded[1])
	new account = (str_to_num(steamid_exploded[2]) * 2) + 60265728 + carry
	new upper = 765611979
	new div = account / 100000000
	new index = 9 - (div ? div / 10 + 1 : 0)
	upper += div
	formatex(buffer[index], len - index, "%d", account)
	index = buffer[9]
	formatex(buffer, len, "%d", upper)
	buffer[9] = index
}
