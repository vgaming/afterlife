-- << afterlife_main

local wesnoth = wesnoth
afterlife = {}
local afterlife = afterlife
local print = print
local ipairs = ipairs
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


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
	id = "afterlife_ai_turn",
	name = "side 2 turn refresh,side 4 turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.ai_turn()" }
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

		local percent = 25 + wesnoth.current.turn * 7
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


function afterlife.ai_turn()
	print("AI moving!")
	if wesnoth.current.turn % 3 == 1 then
		if wesnoth.current.side == 2 then
			copy_units(3, 2, pos2)
		else
			copy_units(1, 4, pos4)
		end
	end
end


wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\". Game rules: Ctrl J")


-- >>
