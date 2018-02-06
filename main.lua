-- << afterlife_main

local wesnoth = wesnoth
afterlife = {}
local afterlife = afterlife
local ipairs = ipairs
local string = string
local helper = wesnoth.require("lua/helper.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local wave_length = 2  -- also change: experience_modifier in _main.cfg, text in about.txt
local copy_strength_start = 20
local copy_strength_increase = 5


local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4
local ai_pos_1 = wesnoth.get_starting_location(ai_side1)
ai_pos_1 = { x = ai_pos_1[1], y = ai_pos_1[2] }
local ai_pos_2 = wesnoth.get_starting_location(ai_side2)
ai_pos_2 = { x = ai_pos_2[1], y = ai_pos_2[2] }


wesnoth.wml_actions.kill {
	canrecruit = true,
	side = ai_side1 .. "," .. ai_side2,
	fire_event = false,
	animate = false,
}
wesnoth.sides[human_side1].base_income = wesnoth.sides[human_side1].base_income + 1


wesnoth.wml_actions.event {
	id = "afterlife_turn_refresh",
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}


local function make_copy(unit_userdata, x, y)
	wesnoth.wml_actions.store_unit {
		T.filter { id = unit_userdata.id },
		variable = "afterlife_unit",
	}
	local unit_var = wesnoth.get_variable("afterlife_unit")
	local id = helper.rand("0..1000000000")
		.. helper.rand("0..1000000000")
		.. helper.rand("0..1000000000")
	unit_var.id = id
	unit_var.underlying_id = id
	unit_var.canrecruit = false
	unit_var.x = x
	unit_var.y = y
	wesnoth.set_variable("afterlife_unit", unit_var)
	wesnoth.wml_actions.unstore_unit {
		variable = "afterlife_unit",
	}
	wesnoth.set_variable("afterlife_unit", nil)
	return id
end


local function copy_units(from_side, to_side, to_pos)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local x, y = wesnoth.find_vacant_tile(to_pos.x, to_pos.y, unit_original)
		local new_id = make_copy(unit_original, x, y)
		local unit = wesnoth.get_units { id = new_id }[1]
		unit.side = to_side
		unit.status.poisoned = false
		unit.status.slowed = false
		unit.status.petrified = true
		unit.variables.afterlife_petrified = true
		unit.moves = unit.max_moves

		local percent = copy_strength_start + wesnoth.current.turn * copy_strength_increase
		local increase_percent = percent - 100
		local ability = T.name_only {
			name = "copy" .. percent ..  "%",
			description = percent .. "% hitpoints, "
				.. percent .. "% damage, "
				.. "unit copied from side " .. from_side
		}
		wesnoth.add_modification(unit, "object", {
			T.effect { apply_to = "attack", increase_damage = increase_percent .. "%" },
			T.effect { apply_to = "hitpoints", increase_total = increase_percent .. "%", heal_full = true },
			T.effect { apply_to = "new_ability", T.abilities { ability } },
		})
	end
end


local function unpetrify_units()
	for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
		if unit.variables.afterlife_petrified then
			unit.status.petrified = false
			unit.variables.afterlife_petrified = nil
		end
	end
end


function afterlife.turn_refresh()
	if wesnoth.current.turn % wave_length == 1 then
		if wesnoth.current.side == 1 then
			copy_units(human_side2, ai_side1, ai_pos_1)
			copy_units(human_side1, ai_side2, ai_pos_2)
			local next_wave_turn = wesnoth.current.turn
				- (wesnoth.current.turn - 2) % wave_length
				+ wave_length - 1
			wesnoth.wml_actions.label {
				x = 8,
				y = 2,
				text = string.format("<span color='#FFFFFF'>Next wave:\n    turn %s</span>", next_wave_turn)
			}
		end
		if wesnoth.current.side == ai_side1 or wesnoth.current.side == ai_side2 then
			unpetrify_units()
		end
	end
end


wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


-- >>
