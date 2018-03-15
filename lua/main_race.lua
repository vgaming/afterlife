-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local math = math
local table = table
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4
local sides = {
	[1] = { enemy_human = 3, enemy_ai = 2, half_owner = 1 },
	[2] = { half_owner = 1},
	[3] = { enemy_human = 1, enemy_ai = 4, half_owner = 3 },
	[4] = { half_owner = 2},
}

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
wesnoth.wml_actions.event {
	id = "afterlife_die",
	name = "die",
	first_time_only = false,
	T.lua { code = "afterlife.die()" }
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


local function generate_wave(side)
	local prev_distance = wesnoth.get_variable("afterlife_distance_" .. side) or height + 1
	local units = wesnoth.get_units { side = side }
	table.sort(units, function(a, b) return a.y > b.y end)
	local new_distance = math.min(prev_distance, units[#units].y)
	wesnoth.set_variable("afterlife_distance_" .. side, new_distance)
	--print("side", side, "distance", new_distance)
	for idx, wave_info in ipairs(waves) do
		if new_distance <= wave_info.y and prev_distance > wave_info.y then
			copy_units(sides[side].enemy_human, sides[side].enemy_ai, waves.strength(idx), wave_info.y - 7)
		end
	end
end


local function check_win(side)
	if (side == human_side1 or side == human_side2)
		and wesnoth.get_variable("afterlife_distance_" .. side) <= waves[#waves].y
		and not wesnoth.wml_conditionals.has_unit { side = sides[side].enemy_ai } then
		wesnoth.wml_actions.kill {
			side = sides[side].enemy_human,
			canrecruit = true,
		}
		wesnoth.wml_actions.endlevel {
			T.result { side = side, result = "victory" },
			T.result { side = sides[side].enemy_human, result = "defeat" },
		}
	end
end


local function die()
	--print("die event", wesnoth.current.side, sides[wesnoth.current.side].half_owner)
	check_win(sides[wesnoth.current.side].half_owner)
end


local function turn_refresh()
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
afterlife.die = die

-- >>
