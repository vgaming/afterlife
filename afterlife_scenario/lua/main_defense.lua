-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local string = string
local math = math
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local is_givecontrol = wesnoth.sides[2].hidden == false

local wave_length = 2  -- also change: experience_modifier in _main.cfg, text in about.txt
local copy_strength_start = 32 -- point of no return is about 50%
local copy_strength_increase = 2


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4
local sides = {
	[1] = { enemy_human = 3, enemy_clone = 2, half_owner = 1 },
	[2] = { half_owner = 1},
	[3] = { enemy_human = 1, enemy_clone = 4, half_owner = 3 },
	[4] = { half_owner = 2},
}


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
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}
wesnoth.wml_actions.event {
	name = "side turn end",
	first_time_only = false,
	T.lua { code = "afterlife.side_turn_end_event()" }
}

local function weaken_copies()
	if wesnoth.current.side == ai_side1 or wesnoth.current.side == ai_side2 then
		for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
			wesnoth.add_modification(unit, "object", {
				T.effect { apply_to = "attack", increase_damage = "-50%" },
				T.effect { apply_to = "hitpoints", increase = "1" },
				T.effect { apply_to = "hitpoints", increase_total = "1" },
				T.effect { apply_to = "hitpoints", increase = "-50%" },
				T.effect { apply_to = "hitpoints", increase_total = "-50%" },
			})
		end
	end
end

local function copy_units(from_side, to_side)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local to_pos = afterlife.find_vacant(unit_original)
		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
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
			afterlife.unpetrify_units(is_givecontrol)
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

function afterlife.side_turn_end_event()
	if is_givecontrol and wesnoth.current.turn % wave_length == 0 then
		weaken_copies()
	end
end


print("active mods:", wesnoth.game_config.mp_settings.active_mods)
wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


-- >>
