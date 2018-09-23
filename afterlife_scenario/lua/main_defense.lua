-- << afterlife/main_defense

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local string = string
local on_event = wesnoth.require("lua/on_event.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local wave_length = 2  -- also change: experience_modifier in _main.cfg, text in about.txt
local copy_strength_start = 32 -- point of no return is about 50%
local copy_strength_increase = 2


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4
local sides = {
	[1] = { enemy_human = 3, enemy_clone = 2, half_owner = 1, is_human = true },
	[2] = { half_owner = 1, is_human = false },
	[3] = { enemy_human = 1, enemy_clone = 4, half_owner = 3, is_human = true },
	[4] = { half_owner = 2, is_human = false },
}

on_event("start", function()
	wesnoth.wml_actions.kill {
		canrecruit = true,
		side = ai_side1 .. "," .. ai_side2,
		fire_event = false,
		animate = false,
	}
	for _, side in ipairs(wesnoth.sides) do
		side.village_support = side.village_support + 2
	end
end)

local function copy_units(from_side, to_side)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
		local to_pos = afterlife.find_vacant(unit_original, nil, true)
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
	if wesnoth.current.turn % wave_length == 1 then
		if wesnoth.current.side == 1 then
			copy_units(human_side2, ai_side1)
			copy_units(human_side1, ai_side2)
		end
		if wesnoth.sides[wesnoth.current.side].__cfg.allow_player == false then
			afterlife.unpetrify_units()
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
end)

on_event("side turn end", function()
	for _, unit in ipairs(wesnoth.get_units { canrecruit = true, side = wesnoth.current.side }) do
		unit.status.uncovered = true
	end
end)


-- >>
