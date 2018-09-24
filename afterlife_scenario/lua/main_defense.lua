-- << afterlife/main_defense

local wesnoth = wesnoth
local afterlife = afterlife
local ipairs = ipairs
local string = string
local wml = wml
local on_event = wesnoth.require("lua/on_event.lua")


local wave_length = #wesnoth.sides == 4 and 2 or 1  -- also change: experience_modifier in _main.cfg, text in about.txt
local copy_strength_start = 32 -- point of no return is about 50%
local copy_strength_increase = 2
local teams = { West = { enemy = "East", humans = {} }, East = { enemy = "West", humans = {} } }
for _, side in ipairs(wesnoth.sides) do
	local team = teams[side.team_name] or {}
	teams[side.team_name] = team
	local is_alive = wml.variables["afterlife_alive_" .. side.side] or #wesnoth.get_units { side = side.side } > 0
	wml.variables["afterlife_alive_" .. side.side] = is_alive
	if side.__cfg.allow_player == false then
		team.ai = side.side
	elseif is_alive then
		team.humans[#team.humans + 1] = side.side
	end
end
-- print_as_json(teams)


on_event("start", function()
	for _, side in ipairs(wesnoth.sides) do
		if side.__cfg.allow_player == false then
			wesnoth.wml_actions.kill {
				canrecruit = true,
				side = side.side,
				fire_event = false,
				animate = false,
			}
		end
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
	if (wesnoth.current.turn + 1) % wave_length == 0 then
		if wesnoth.current.side == 1 then
			copy_units(teams.West.humans[wesnoth.current.turn % #teams.West.humans + 1], teams.West.ai)
			copy_units(teams.East.humans[wesnoth.current.turn % #teams.East.humans + 1], teams.East.ai)
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
