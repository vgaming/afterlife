-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local math = math
local table = table
local on_event = wesnoth.require("lua/on_event.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}

afterlife.schedule_attack_abort_triggers()

local human_side1, human_side2 = 1, 3
local sides = {
	[1] = { enemy_human = 3, enemy_ai = 2, half_owner = 1 },
	[2] = { half_owner = 1 },
	[3] = { enemy_human = 1, enemy_ai = 4, half_owner = 3 },
	[4] = { half_owner = 2 },
}

wesnoth.wml_actions.event {
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh_event()" }
}
wesnoth.wml_actions.event {
	name = "die",
	first_time_only = false,
	T.lua { code = "afterlife.die_event()" }
}
wesnoth.wml_actions.event {
	name = "prestart",
	first_time_only = false,
	T.lua { code = "afterlife.prestart_event()" }
}

local waves = {}
local wave_count = wesnoth.get_variable("afterlife_wave_count_20210911") or 12 -- also change default in WML
for _, side in ipairs(wesnoth.sides) do
	local diff = (wave_count < 7 and 2) or (wave_count < 10 and 1) or 0
	side.village_gold = side.village_gold + diff
	side.village_support = side.village_support + diff
end
for idx = 0, wave_count - 1 do
	local step = wave_count > 12 and 35 / (wave_count - 1) or 35 / 11
	local y = math.floor(41 - idx * step + 0.5)
	waves[#waves + 1] = { y = y }
end
waves.strength = function(idx) return math.floor(40 + 30 * (idx - 1) / (#waves - 1) + 0.5) end

local width, height, border = wesnoth.get_map_size()
local left_label, right_label = border + math.floor(width * 1 / 4), border + math.floor(width * 3 / 4)


local function copy_units(from_side, to_side, copy_strength, y_min)
	--print("generating wave", from_side, to_side, copy_strength, y_min)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local to_pos = afterlife.find_vacant(unit_original, y_min)
		afterlife.copy_unit(unit_original, to_pos, to_side, copy_strength)
	end
end


local function generate_wave(side)
	local prev_distance = wesnoth.get_variable("afterlife_distance_" .. side) or height + 1
	local units = wesnoth.get_units { side = side }
	table.sort(units, function(a, b) return a.y > b.y end)
	local new_distance = math.min(prev_distance, units[#units].y)
	wesnoth.set_variable("afterlife_distance_" .. side, new_distance)
	--print("side", side, "distance", new_distance)
	for idx, wave_info in ipairs(waves) do
		if new_distance <= wave_info.y and prev_distance > wave_info.y then
			(wesnoth.label or wesnoth.wml_actions.label) {
				x = side == human_side1 and left_label or right_label,
				y = wave_info.y,
				text = "",
			}
			copy_units(sides[side].enemy_human, sides[side].enemy_ai, waves.strength(idx), wave_info.y - 7)
		end
	end
end


local function check_win(side)
	if (side == human_side1 or side == human_side2)
		and wesnoth.get_variable("afterlife_distance_" .. side) <= waves[#waves].y
		and not wesnoth.wml_conditionals.has_unit { side = sides[side].enemy_ai } then
		afterlife.endlevel_team(wesnoth.sides[side].team_name)
	end
end


local function green_to_red(frac)
	local red = math.min(255, math.ceil(frac * 2 * 255))
	local green = math.min(255, math.ceil(255 * 2 - frac * 2 * 255))
	return { red, green, 0, 255 }
end


function afterlife.prestart_event()
	for _, side in ipairs(wesnoth.sides) do
		side.village_support = side.village_support + 1
	end
	afterlife.kill_ai_leaders()
	for wave_index, wave_info in ipairs(waves) do
		for _, x in ipairs { left_label, right_label } do
			(wesnoth.label or wesnoth.wml_actions.label) {
				x = x,
				y = wave_info.y,
				color = green_to_red(wave_index / #waves),
				text = "____" .. waves.strength(wave_index) .. "%____",
			}
		end
	end
end


local function turn_refresh_event()
	if wesnoth.current.side == 1 then
		generate_wave(human_side1)
		generate_wave(human_side2)
	end
	if wesnoth.current.side == human_side2 then
		check_win(human_side1)
	end
	if wesnoth.current.side == human_side1 then
		check_win(human_side2)
	end
	afterlife.unpetrify_units()
end


function afterlife.die_event()
	--print("die event", wesnoth.current.side, sides[wesnoth.current.side].half_owner)
	check_win(sides[wesnoth.current.side].half_owner)
end


on_event("start", function()
	for _ = 0, 46 do
		afterlife.scroll_terrain_down()
	end
	wesnoth.wml_actions.redraw {}
end)
afterlife.turn_refresh_event = turn_refresh_event

-- >>
