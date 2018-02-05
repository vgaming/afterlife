-- << afterlife_main

local wesnoth = wesnoth
afterlife = {}
local afterlife = afterlife
local ipairs = ipairs
local string = string
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local wave_length = 2  -- also change experience_modifier in _main.cfg
local copy_strength_start = 20
local copy_strength_increase = 5


wesnoth.wml_actions.kill {
	canrecruit = true,
	side = "2,4",
	fire_event = false,
	animate = false,
}


local pos2 = wesnoth.get_starting_location(2)
pos2 = { x = pos2[1], y = pos2[2] }
local pos4 = wesnoth.get_starting_location(4)
pos4 = { x = pos4[1], y = pos4[2] }


wesnoth.wml_actions.event {
	id = "afterlife_turn_refresh",
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}


local function set_canrecruit(unit_userdata, canrecruit)
		wesnoth.wml_actions.store_unit {
			T.filter { id = unit_userdata.id },
			variable = "afterlife_unit",
		}
		local unit_var = wesnoth.get_variable("afterlife_unit")
		unit_var.canrecruit = canrecruit or false
		wesnoth.set_variable("afterlife_unit", unit_var)
		wesnoth.wml_actions.unstore_unit {
			variable = "afterlife_unit",
		}
		wesnoth.set_variable("afterlife_unit", nil)
end


local function copy_units(from_side, to_side, to_pos)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local unit = wesnoth.copy_unit(unit_original)
		unit.side = to_side
		unit.status.poisoned = false
		unit.status.slowed = false
		unit.status.petrified = false
		local x, y = wesnoth.find_vacant_tile(to_pos.x, to_pos.y, unit)
		unit.x = x
		unit.y = y
		unit.moves = unit.max_moves

		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
		local increase_percent = percent - 100
		local ability = T.name_only {
			name = "copy" .. percent ..  "%",
			description = "unit copied from side " .. from_side .. ", "
				.. percent .. "% hitpoints, "
				.. percent .. "% damage"
		}
		wesnoth.add_modification(unit, "object", {
			T.effect { apply_to = "attack", increase_damage = increase_percent .. "%" },
			T.effect { apply_to = "hitpoints", increase_total = increase_percent .. "%", heal_full = true },
			T.effect { apply_to = "new_ability", T.abilities { ability } },
		})

		wesnoth.put_unit(unit)
		set_canrecruit(unit, false)
	end
end


function afterlife.turn_refresh()
	if wesnoth.current.turn % wave_length == 1 then
		if wesnoth.current.side == 2 then
			copy_units(3, 2, pos2)
		elseif wesnoth.current.side == 4 then
			copy_units(1, 4, pos4)
		end
	end
	local next_wave_turn = wesnoth.current.turn
		- (wesnoth.current.turn - 2) % wave_length
		+ wave_length - 1
	wesnoth.wml_actions.label {
		x = 8,
		y = 2,
		text = string.format("<span color='#FFFFFF'>Next wave:\n    turn %s</span>", next_wave_turn)
	}
end


wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


-- >>
