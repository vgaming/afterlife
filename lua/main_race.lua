-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local error = error
local ipairs = ipairs
local math = math
local table = table
local string = string
local helper = wesnoth.require("lua/helper.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4

for _, side in ipairs(wesnoth.sides) do
	side.village_support = side.village_support + 1
end

wesnoth.wml_actions.kill {
	canrecruit = true,
	side = ai_side1 .. "," .. ai_side2,
	fire_event = false,
	animate = false,
}

wesnoth.wml_actions.event {
	id = "afterlife_turn_refresh",
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}

local waves = {
	{ y = 41 }, -- 1
	{ y = 38 },
	{ y = 34 },
	{ y = 30 },
	{ y = 26 },
	{ y = 22 },
	{ y = 18 },
	{ y = 14 },
	{ y = 10 },
	{ y = 6 }, -- 10
	strength = function(idx) return 40 + idx * 3 end
}

local width, height, border = wesnoth.get_map_size()


local function copy_units(from_side, to_side, copy_strength, y_min)
	print("making wave", from_side, to_side, copy_strength, y_min)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local to_pos = afterlife.find_vacant(unit_original, y_min)
		afterlife.copy_unit(unit_original, to_pos, to_side, copy_strength)
	end
end


local function generate_wave(side, enemy_human, enemy_ai)
	local prev_distance = wesnoth.get_variable("afterlife_distance_" .. side) or height + 1
	local units = wesnoth.get_units { side = side }
	table.sort(units, function(a, b) return a.y > b.y end)
	local new_distance = units[#units].y
	wesnoth.set_variable("afterlife_distance_" .. side, new_distance)
	print("side", side, "distance", new_distance)
	for idx, wave_info in ipairs(waves) do
		if new_distance <= wave_info.y and prev_distance > wave_info.y then
			copy_units(enemy_human, enemy_ai, waves.strength(idx), new_distance - 8)
		end
	end
end


local function check_win(side, enemy_ai, enemy_human)
	if wesnoth.current.side == enemy_human
		and wesnoth.get_variable("afterlife_distance_" .. side) <= waves[#waves].y
		and #wesnoth.get_units { side = enemy_ai } == 0 then
		wesnoth.wml_actions.kill {
			side = enemy_human,
			canrecruit = true,
		}
	end
end


local function turn_refresh()
	if wesnoth.current.side == 1 then
		generate_wave(human_side1, human_side2, ai_side1)
		generate_wave(human_side2, human_side1, ai_side2)
	end
	check_win(human_side1, ai_side1, human_side2)
	check_win(human_side2, ai_side2, human_side1)
	afterlife.unpetrify_units()
end


--"85,255,0", "170,255,0", "255,255,0",
--"255,170,0", "255,85,0", "255,0,0"
local function green_to_red(frac)
	local red = math.min(255, math.ceil(frac * 2 * 255))
	local green = math.min(255, math.ceil(255 * 2 - frac * 2 * 255))
	if wesnoth.compare_versions(wesnoth.game_config.version, ">=", "1.13.0") then
		return {red, green, 0, 255}
	else
		return red .. "," .. green .. ",0"
	end
end

for wave_index, wave_info in ipairs(waves) do
	for _, x in ipairs { border + math.floor(width * 1 / 4), border + math.floor(width * 3 / 4) } do
		(wesnoth.label or wesnoth.wml_actions.label) {
			x = x,
			y = wave_info.y,
			color = green_to_red((wave_index) / #waves),
			text = "____" .. waves.strength(wave_index) .. "%____",
		}
	end
end
print("active mods:", wesnoth.game_config.mp_settings.active_mods)
wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


afterlife.turn_refresh = turn_refresh

-- >>
