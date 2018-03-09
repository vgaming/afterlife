-- << utils_afterlife

afterlife = {}
local afterlife = afterlife
local wesnoth = wesnoth
local ipairs = ipairs
local helper = wesnoth.require("lua/helper.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}

local function unit_wml_transform(unit_userdata, x, y)
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


local function copy_unit(unit_original, to_pos, to_side, strength_percent)
	local from_side = unit_original.side
	if to_pos == nil or to_pos.x == nil then return end
	local new_id = unit_wml_transform(unit_original, to_pos.x, to_pos.y)
	local unit = wesnoth.get_units { id = new_id }[1]
	unit.side = to_side
	unit.status.poisoned = false
	unit.status.slowed = false
	unit.status.petrified = true
	unit.variables.afterlife_petrified = true
	unit.moves = unit.max_moves

	local increase_percent = strength_percent - 100
	local ability = T.name_only {
		name = "copy" .. strength_percent ..  "%",
		description = strength_percent .. "% hitpoints, "
			.. strength_percent .. "% damage, "
			.. "unit copied from side " .. from_side
	}
	wesnoth.add_modification(unit, "object", {
		T.effect { apply_to = "attack", increase_damage = increase_percent .. "%" },
		T.effect { apply_to = "hitpoints", increase_total = increase_percent .. "%", heal_full = true },
		T.effect { apply_to = "new_ability", T.abilities { ability } },
	})
end


local function unpetrify_units()
	for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
		if unit.variables.afterlife_petrified then
			unit.status.petrified = false
			unit.variables.afterlife_petrified = nil
		end
	end
end


afterlife.copy_unit = copy_unit
afterlife.unpetrify_units = unpetrify_units

-- >>
