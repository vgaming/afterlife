-- << main_defense | afterlife_scenario
local filename = "main_defense | afterlife_scenario"
if afterlife.is_loaded(filename) then
	return
end

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local math = math
local string = string
local wml = wml
local on_event = wesnoth.require("lua/on_event.lua")


local is_team = #wesnoth.sides == 6
local copy_strength_start = is_team and 26 or 32 -- point of no return is about 50%
local copy_strength_increase = 2
local teams = {}
for _, side in ipairs(wesnoth.sides) do
	local team_id = teams[side.team_name] or (#teams + 1);
	teams[side.team_name] = team_id;
	local team = teams[team_id] or { enemy = 3 - team_id, humans = {} };
	teams[team_id] = team
	local is_alive = wml.variables["afterlife_alive_" .. side.side] or #wesnoth.units.find_on_map { side = side.side } > 0
	wml.variables["afterlife_alive_" .. side.side] = is_alive
	if side.__cfg.allow_player == false then
		team.ai = side.side
	elseif is_alive then
		team.humans[#team.humans + 1] = side.side
	end
end
-- print_as_json(teams)


on_event("start", function()
	afterlife.kill_ai_leaders()
	for _, side in ipairs(wesnoth.sides) do
		side.village_support = side.village_support + 2
	end
end)

afterlife.schedule_attack_abort_triggers()

local ai_starting_location_y = wesnoth.sides[#wesnoth.sides].starting_location[2]
local function copy_units(from_side, to_side)
	for _, unit_original in ipairs(wesnoth.units.find_on_map { side = from_side }) do
		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
		local to_pos = afterlife.find_vacant(unit_original, ai_starting_location_y, true, is_team)
		if to_pos == nil then
			wesnoth.wml_actions.message {
				speaker = "narrator",
				message = "No free space to place a copy",
			}
			afterlife.endlevel_team(from_side, wesnoth.sides[from_side].team_name)
			break
		else
			afterlife.copy_unit(unit_original, to_pos, to_side, percent)
		end
	end
end

on_event("turn refresh", function()
	local wave_length = afterlife.get_variable("afterlife_wave_length") or 2
	if (wesnoth.current.turn - 1) % wave_length == 0 then
		if wesnoth.current.side == 1 then
			--print_as_json("It is now turn refresh, side 1, and we'll copy units")
			copy_units(teams[1].humans[wesnoth.current.turn % #teams[1].humans + 1], teams[1].ai)
			copy_units(teams[2].humans[wesnoth.current.turn % #teams[2].humans + 1], teams[2].ai)
		end
		if wesnoth.sides[wesnoth.current.side].__cfg.allow_player == false then
			afterlife.unpetrify_units()
		end
	end
	-- print("turn", wesnoth.current.turn, "side", wesnoth.current.side, "div", (wesnoth.current.turn - 2) % wave_length)
	if wave_length > 1 then
		local next_wave_turn = wesnoth.current.turn
			- (wesnoth.current.turn - 2) % wave_length
			+ wave_length - 1
		wesnoth.wml_actions.label {
			x = math.ceil(wesnoth.current.map.playable_width / 2),
			y = 2,
			text = string.format("<span color='#FFFFFF'>Next wave:\n    turn %s</span>", next_wave_turn)
		}
	end
end)

on_event("side turn end", function()
	for _, unit in ipairs(wesnoth.units.find_on_map { canrecruit = true, side = wesnoth.current.side }) do
		unit.status.uncovered = true
	end
end)


-- >>
