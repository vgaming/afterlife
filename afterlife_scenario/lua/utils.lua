-- << utils_afterlife

afterlife = {}
local afterlife = afterlife
local wesnoth = wesnoth
local ipairs = ipairs
local math = math
local string = string
local helper = wesnoth.require("lua/helper.lua")
local on_event = wesnoth.require("lua/on_event.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


wesnoth.wml_conditionals = wesnoth.wml_conditionals or {}
wesnoth.wml_conditionals.has_unit = wesnoth.wml_conditionals.has_unit or function(cfg)
	afterlife.temp = false
	wesnoth.wml_actions["if"] {
		T.have_unit(cfg),
		T["then"] { T.lua { code = "afterlife.temp = true" } }
	}
	return afterlife.temp
end


local function unit_wml_copy(unit_userdata, x, y)
	wesnoth.wml_actions.store_unit {
		T.filter { id = unit_userdata.id },
		variable = "afterlife_unit",
	}
	local unit_var = wesnoth.get_variable("afterlife_unit")
	local id = "afterlife_"
		.. helper.rand("0..1000000000")
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
	if to_pos == nil then return end
	if unit_original.type == "Fog Clearer" then return end
	local from_side = unit_original.side
	local new_id = unit_wml_copy(unit_original, to_pos.x, to_pos.y)
	local unit = wesnoth.get_units { id = new_id }[1]
	unit.side = to_side
	unit.status.poisoned = false
	unit.status.slowed = false
	unit.variables.afterlife_fresh_copy = true
	unit.moves = unit.max_moves
	wesnoth.add_modification(unit, "object", {
		id = "afterlife_grayscale",
		T.effect { apply_to = "image_mod", add="GS()" },
		T.effect { apply_to = "zoc", value = false },
	})
	unit.status.petrified = false
	unit.status.invulnerable = true

	local increase_percent = strength_percent - 100
	local ability = T.name_only {
		name = "copy" .. strength_percent ..  "%",
		description = strength_percent .. "% hitpoints, "
			.. strength_percent .. "% damage, "
			.. "unit copied from side " .. from_side
	}
	wesnoth.add_modification(unit, "object", {
		T.effect { apply_to = "attack", increase_damage = increase_percent .. "%" },
		T.effect { apply_to = "hitpoints", increase_total = increase_percent .. "%" },
		T.effect { apply_to = "new_ability", T.abilities { ability } },
	})
	unit.hitpoints = unit.max_hitpoints
end


local function unpetrify_units()
	local status_filter = "invulnerable"
	local filtered_units = wesnoth.get_units { side = wesnoth.current.side, status = status_filter }
	for _, unit in ipairs(filtered_units) do
		if unit.variables.afterlife_fresh_copy then
			unit.status.petrified = false
			unit.status.invulnerable = false
			unit.variables.afterlife_fresh_copy = nil
			wesnoth.wml_actions.remove_object {
				id = unit.id,
				object_id = "afterlife_grayscale",
			}
			local img = string.gsub(unit.image_mods, "GS%(%)$", "NOP()", 1)
			wesnoth.add_modification(unit, "object", {
				T.effect { apply_to = "image_mod", replace = img },
			})
		end
	end
end


local width, height, border = wesnoth.get_map_size()
local half = (width - 1) / 2
local left_edge = border
local left_center = half + border - 1
local right_center = half + border + 1
local right_edge = border + width - 1

afterlife.random_terrains = {
	"Gs", "Gd", "Gg", "Gs", "Gd", "Gg", -- grass
	"Wwf", "Wwf", "Wwf", "Wwf", "Wwf", "Wwf", "Wwf", "Wwf", "Wwf", -- ford
	"Gll^Fp", "Gs^Fms", -- forest
	"Mm", -- mountain
	"Ai", -- ice
	"Hh", "Hhd", -- hills
	"Uu^Uf", "Uu^Uf", -- mushrooms,
	"Dd^Do", "Dd^Do", -- oasis
	"Ss", -- swamp
	"Gs^Vh" -- village
}


afterlife.terrain_base_probabilities = {
	{ terrain = "Gs", base = 2 }, -- grass
	{ terrain = "Gd", base = 2 }, -- grass
	{ terrain = "Gg", base = 1 }, -- grass
	{ terrain = "Wwf", base = 9 }, -- ford
	{ terrain = "Gs^Fms", base = 1 }, -- forest
	{ terrain = "Gll^Fp", base = 1 }, -- forest
	{ terrain = "Mm", base = 1 }, -- mountain
	{ terrain = "Ai", base = 1 }, -- ice
	{ terrain = "Hh", base = 1 }, -- hill
	{ terrain = "Hhd", base = 1 }, -- dry hill
	{ terrain = "Uu^Uf", base = 2 }, -- mushrooms
	{ terrain = "Dd^Do", base = 1 }, -- oasis
	{ terrain = "Ss", base = 1 }, -- swamp
	{ terrain = "Gs^Vh", base = 1 } -- village
}

local function get_terrain_probability(i)
	return wesnoth.get_variable("afterlife_terrain_prob_" .. i) or 1
end
local function set_terrain_probability(i, value)
	wesnoth.set_variable("afterlife_terrain_prob_" .. i, value)
end

function afterlife.random_terrain()
	local total = 0
	for index, item in ipairs(afterlife.terrain_base_probabilities) do
		local probability = get_terrain_probability(index) + item.base
		set_terrain_probability(index, probability)
		total = total + probability
	end
	local offset = helper.rand("1.." .. total)
	for index, item in ipairs(afterlife.terrain_base_probabilities) do
		local probability = get_terrain_probability(index)
		offset = offset - probability
		if offset <= 0 then
			set_terrain_probability(index, math.ceil(probability / 2))
			return item.terrain
		end
	end
	return "Aa^Ecf" -- snow with fire (to see the error)
end


function afterlife.scroll_terrain_down()
	local scrolls = wesnoth.get_variable("afterlife_scrolls") or 0
	wesnoth.set_variable("afterlife_scrolls", scrolls + 1)

	for y = height - 1, border, -1 do
		for x = left_edge, right_edge do
			local upper_terrain = wesnoth.get_terrain(x, y - 1)
			wesnoth.set_terrain(x, y, upper_terrain)
			wesnoth.set_village_owner(x, y, wesnoth.get_village_owner(x, y - 1), false)
		end
	end
	local y = border - 1
	for x = left_edge, left_center do
		local rem = scrolls % 10
		local terrain
		if x == left_center and rem >= 7 and rem <= 9 then
			terrain = "Kh"
		elseif x == left_edge and rem >= 2 and rem <= 4 then
			terrain = "Kh"
		else
			terrain = afterlife.random_terrain()
		end
		wesnoth.set_terrain(x, y, terrain)
		wesnoth.set_terrain(width - x + 1, y, terrain)
	end
end


function afterlife.scroll_units_down()
	for y = height, 0, -1 do
		for _, unit in ipairs(wesnoth.get_units { y = y }) do
			local current_terrain = wesnoth.get_terrain(unit.x, unit.y)
			if y == height or wesnoth.unit_movement_cost(unit, current_terrain) > 10 then
				wesnoth.wml_actions.kill {
					id = unit.id,
					fire_event = true,
					animate = true,
				}
			else
				unit.y = unit.y + 1
			end
		end
	end
end


function afterlife.schedule_scrolling_down(frequency)
	on_event("start", function()
		for _ = height, 0, -1 do
			afterlife.scroll_terrain_down()
		end
		wesnoth.wml_actions.redraw {}
	end)
	on_event("side turn end", function()
		local micro_turn = (wesnoth.get_variable("afterlife_micro_turns") or 0) + 1
		wesnoth.set_variable("afterlife_micro_turns", micro_turn)
		if micro_turn % frequency == 0 then
			afterlife.scroll_terrain_down()
			afterlife.scroll_units_down()
			wesnoth.wml_actions.redraw {}
		end
	end)
end


function afterlife.find_vacant(unit, y_min, honor_edge, flip)
	y_min = y_min or border
	y_min = math.max(border, y_min)
	local x_start = unit.x < right_center and right_center or left_center
	local x_end = unit.x < right_center and right_edge or left_edge
	if flip then x_start, x_end = x_end, x_start end
	local x_step = (x_end - x_start) / math.abs(x_end - x_start)
	for y = y_min, height do
		for x = x_start, x_end, x_step do
			local is_edge = honor_edge and y == y_min and x == x_start
			if wesnoth.wml_conditionals.has_unit { x = x, y = y } == false
				and wesnoth.get_terrain(x, y) ~= "Xv"
				and not is_edge then
				return { x = x, y = y }
			end
		end
	end
end


function afterlife.kill_ai_leaders()
	for _, side in ipairs(wesnoth.sides) do
		if side.__cfg.allow_player == false then
			wesnoth.wml_actions.kill {
				canrecruit = true,
				side = side.side,
				fire_event = false,
				animate = false,
			}
		end
	end
end


local function endlevel_team(winner_team)
	local i_am_winner = false
	for _, side in ipairs(wesnoth.sides) do
		if side.team_name ~= winner_team and side.__cfg.allow_player == true then
			wesnoth.wml_actions.kill {
				side = side.side,
			}
		end
		if side.team_name == winner_team and side.__cfg.allow_player == true and side.is_local then
			i_am_winner = true
		end
	end

	wesnoth.wml_actions.endlevel {
		result = i_am_winner and "victory" or "defeat"
	}
end


print("active mods:", wesnoth.game_config.mp_settings.active_mods)


afterlife.endlevel_team = endlevel_team
afterlife.copy_unit = copy_unit
afterlife.unpetrify_units = unpetrify_units

-- >>
