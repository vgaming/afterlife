-- << utils_afterlife

afterlife = {}
local afterlife = afterlife
local wesnoth = wesnoth
local ipairs = ipairs
local math = math
local string = string
local table = table
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
	wesnoth.set_village_owner(to_pos.x, to_pos.y, to_side, false)
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
			local img = string.gsub(unit.image_mods, "GS%(%)", "NOP()", 1)
			wesnoth.add_modification(unit, "object", {
				T.effect { apply_to = "image_mod", replace = img },
			})
		end
	end
end

function afterlife.schedule_attack_abort_triggers()
	local invulnerable
	on_event("attack", function()
		local event = wesnoth.current.event_context
		local event_unit = wesnoth.units.find_on_map { x = event.x2, y = event.y2 }[1]
		if event_unit ~= nil and event_unit.variables.afterlife_fresh_copy == true then
			invulnerable = event_unit
			invulnerable:to_recall()
		end
	end)
	on_event("attack end", function()
		if invulnerable then
			invulnerable:to_map()
			invulnerable = nil
		end
	end)
end


local width, height, border = wesnoth.get_map_size()
local half = (width - 1) / 2
local left_edge = border
local left_center = half + border - 1
local right_center = half + border + 1
local right_edge = border + width - 1

local terrain_base_probabilities = {
	["Gs"] = 4, -- grass
	["Gd"] = 4, -- grass
	["Gg"] = 3, -- grass
	["Wwf"] = 28 , -- ford
	["Gs^Fms"] = 2, -- forest
	["Gll^Fp"] = 2, -- forest
	["Mm"] = 1, -- mountain
	["Ai"] = 1, -- ice
	["Hh"] = 2, -- hill
	["Hhd"] = 2, -- dry hill
	["Uu^Uf"] = 2, -- mushrooms
	["Dd^Do"] = 1, -- oasis
	["Ss"] = 1, -- swamp
	["Gs^Vh"] = 2, -- village
}
local terrain_variability_multiplier = 1 -- how variable terrain will be
local terrain_iterator = {}
local terrain_total = 0
local function set_probability(terrain_index, value)
	wesnoth.set_variable("afterlife_terrain_prob_" .. terrain_index, value)
end
local function get_probability(terrain_index)
	return wesnoth.get_variable("afterlife_terrain_prob_" .. terrain_index)
end

for terr, value in pairs(terrain_base_probabilities) do
	-- We will need to sort this later because `pairs` is an unordered (OOS-unsafe) iterator
	terrain_total = terrain_total + value
	terrain_iterator[#terrain_iterator + 1] = terr
end
table.sort(terrain_iterator)
for idx, terr in ipairs(terrain_iterator) do
	if get_probability(idx) == nil then
		local base = terrain_base_probabilities[terr]
		set_probability(idx, base * terrain_variability_multiplier)
	end
end

local function random_terrain()
	local offset = helper.rand("1.." .. terrain_total * terrain_variability_multiplier)
	for idx, terrain in ipairs(terrain_iterator) do
		offset = offset - get_probability(idx)
		if offset <= 0 then
			-- Now that this terrain is chosen, decrease the chosen terr probability by total,
			-- and add a distributed base to all terrains
			set_probability(idx, get_probability(idx) - terrain_total)
			for small_idx, small_terrain in ipairs(terrain_iterator) do
				local base = terrain_base_probabilities[small_terrain]
				set_probability(small_idx, get_probability(small_idx) + base)
			end
			return terrain
		end
	end
	return "Aa^Ecf" -- snow with fire (to see the error)
end


function afterlife.scroll_terrain_down()
	local castle_length = math.ceil(width / 6)
	local scrolls = wesnoth.get_variable("afterlife_scrolls") or 0
	wesnoth.set_variable("afterlife_scrolls", scrolls + 1)

	for y = height - 1, border, -1 do
		for x = left_edge, right_edge do
			local upper_terrain = wesnoth.get_terrain(x, y - 1)
			wesnoth.set_terrain(x, y, upper_terrain)
			wesnoth.set_village_owner(x, y, wesnoth.get_village_owner(x, y - 1), false)
			if _G.bonustile and _G.bonustile.exported_change_bonus_position_v1 then
				bonustile.exported_change_bonus_position_v1(x, y - 1, x, y)
			end
		end
	end
	local y = border - 1
	for x = left_edge, left_center do
		local rem = scrolls % (castle_length * 4 - 2)
		local terrain
		if x == left_center and rem >= castle_length * 2 + 1 and rem <= castle_length * 3 then
			terrain = "Kh"
		elseif x == left_edge and rem >= 2 and rem <= castle_length + 1 then
			terrain = "Kh"
		else
			terrain = random_terrain()
		end
		wesnoth.set_terrain(x, y, terrain)
		wesnoth.set_terrain(width - x + 1, y, terrain)
	end
end

function afterlife.scroll_units_down()
	for _, unit in ipairs(wesnoth.get_units { y = height }) do
		wesnoth.wml_actions.kill {
			id = unit.id,
			fire_event = true,
			animate = true,
		}
	end
	for y = height - 1, 0, -1 do
		for _, unit in ipairs(wesnoth.get_units { y = y }) do
			unit.y = unit.y + 1
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
		local micro_turn = (wesnoth.current.turn - 1) * #wesnoth.sides + wesnoth.current.side - 4
		if micro_turn % frequency == 0 then
			afterlife.scroll_units_down()
			afterlife.scroll_terrain_down()
			wesnoth.wml_actions.redraw {}
		end
	end)
end


function afterlife.find_vacant(unit, y_min, honor_edge, flip)
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
