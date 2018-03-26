-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local string = string
local math = math
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local wave_length = 2  -- also change: experience_modifier in _main.cfg, text in about.txt
local copy_strength_start = 32 -- point of no return is about 50%
local copy_strength_increase = 2


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4


wesnoth.wml_actions.kill {
	canrecruit = true,
	side = ai_side1 .. "," .. ai_side2,
	fire_event = false,
	animate = false,
}
wesnoth.sides[human_side1].base_income = wesnoth.sides[human_side1].base_income + 0
for _, side in ipairs(wesnoth.sides) do
	side.village_support = side.village_support + 2
end


wesnoth.wml_actions.event {
	id = "afterlife_turn_refresh",
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}
wesnoth.wml_actions.event {
	id = "afterlife_side_turn",
	name = "side turn",
	first_time_only = false,
	T.lua { code = "afterlife.side_turn_event()" }
}

local function copy_units(from_side, to_side)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local to_pos = afterlife.find_vacant(unit_original)
		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
		if wesnoth.get_variable("afterlife_givecontrol") then
			percent = math.floor(percent * 2 / 3)
		end
		afterlife.copy_unit(unit_original, to_pos, to_side, percent)
	end
end


function afterlife.turn_refresh()
	if wesnoth.current.turn % wave_length == 1 then
		if wesnoth.current.side == 1 then
			copy_units(human_side2, ai_side1)
			copy_units(human_side1, ai_side2)
		end
		if wesnoth.current.side == ai_side1 or wesnoth.current.side == ai_side2 then
			afterlife.release_wave(wesnoth.get_variable("afterlife_givecontrol"))
		end
	end
	-- print("turn", wesnoth.current.turn, "side", wesnoth.current.side, "div", (wesnoth.current.turn - 2) % wave_length)
	local next_wave_turn = wesnoth.current.turn
		- (wesnoth.current.turn - 2) % wave_length
		+ wave_length - 1
	wesnoth.wml_actions.label {
		x = 8,
		y = 2,
		text = string.format("<span color='#FFFFFF'>Next wave:\n    turn %s</span>", next_wave_turn)
	}
end


function afterlife.side_turn_event()
	if wesnoth.get_variable("afterlife_givecontrol") then
		print("applying givecontrol...")
		if wesnoth.current.side == human_side1 then
			wesnoth.sides[ai_side2].controller = "null"
			wesnoth.sides[ai_side2].controller = "human"
		elseif wesnoth.current.side == human_side2 then
			wesnoth.sides[ai_side1].controller = "null"
			wesnoth.sides[ai_side1].controller = "human"
		end
	end
end


print("active mods:", wesnoth.game_config.mp_settings.active_mods)
wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


-- >>
