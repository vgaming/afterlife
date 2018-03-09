-- << afterlife_main

local wesnoth = wesnoth
local afterlife = afterlife
local assert = assert
local error = error
local ipairs = ipairs
local math = math
local table = table
local string = string
local helper = wesnoth.require("lua/helper.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


local wave_length = 2  -- also change: text in about.txt
local human_side1, human_side2 = 1,3
local ai_side1, ai_side2 = 2,4

local kilometers_endgame = 21
wesnoth.set_variable("afterlife_kilometers_endgame", kilometers_endgame)

for _, side in ipairs(wesnoth.sides) do
	side.base_income = side.base_income + 10
end

wesnoth.wml_actions.kill {
	canrecruit = true,
	side = ai_side1 .. "," .. ai_side2,
	fire_event = false,
	animate = false,
}

wesnoth.wml_actions.event {
	id = "afterlife_turn_refresh",
	name = "turn refresh",
	first_time_only = false,
	T.lua { code = "afterlife.turn_refresh()" }
}

local terrains = {
	{2, "Mm"}, -- mountain
	{1, "Md"}, -- mountain
	{3, "Hh"}, -- hill
	{4, "Hhd"}, -- hill
	{2, "Gs^Ft"}, -- forest
	{2, "Gs^Fds"}, -- forest
	{2, "Gll^Fp"}, -- forest
	{2, "Gll^Fdw"}, -- forest
	{2, "Gll^Fdf"}, -- forest
	{10, "Wwf"}, -- ford
	{5, "Ss"}, -- swamp
	{12, "Dd^Do"}, -- oasis
	{10, "Gg"}, -- grass
	{10, "Gs"}, -- grass2
	{10, "Gd"}, -- grass3
	{10, "Gll"}, -- grass4
}
local base_probability = {}
for _, terr in ipairs(terrains) do
	base_probability[terr[2]] = terr[1]
end
local accumulated = {}
local terrain_sum = 0
for _, terr in ipairs(terrains) do
	terrain_sum = terrain_sum + terr[1]
	accumulated[#accumulated + 1] = { terrain_sum, terr[2] }
end
local function rand_terrain()
	local rand = helper.rand("0.." .. terrain_sum)
	--print("rand", rand)
	for _, terr in ipairs(accumulated) do
		if rand <= terr[1] then  -- binary search? Haven't heard of.
			return terr[2]
		end
	end
	error("no terrain found")
end


local width, height, border = wesnoth.get_map_size()
local half_width = (width - 1) / 2
local function x_start_func(is_left)
	return border + (is_left and 0 or half_width + 1)
end

local function scroll_terrain(is_left, distance)
	for y = height - 1, distance, -1 do
		local x_start = x_start_func(is_left)
		for x = x_start, x_start + half_width - 1 do
			local t = wesnoth.get_terrain(x, y - distance)
			wesnoth.set_terrain(x, y, wesnoth.get_terrain(x, y - distance))
		end
	end
	local x_start = x_start_func(is_left)
	for y = distance, 0, -1 do
		for x = x_start, x_start + half_width - 1 do
			wesnoth.set_terrain(x, y, rand_terrain())
		end
	end
end


local function copy_units(from_side, to_side, percent)
	for _, unit_original in ipairs(wesnoth.get_units { side = from_side }) do
		local to_pos = afterlife.find_vacant(unit_original)
		afterlife.copy_unit(unit_original, to_pos, to_side, percent)
	end
end

local function scroll_down(sides, is_left, enemy)
	local function sorting_f(a, b) return a.y > b.y end
	local units = wesnoth.get_units { side = sides }
	table.sort(units, sorting_f)
	local distance = math.min(5, height - units[1].y)
	for _, unit in ipairs(units) do
		wesnoth.put_unit(unit.x, unit.y + distance, unit)
	end
	scroll_terrain(is_left, wesnoth.current.turn == 1 and height -1 or distance)
	local kilometers = wesnoth.get_variable("afterlife_km_" .. sides) or 0
	kilometers = kilometers + distance
	wesnoth.set_variable("afterlife_km_" .. sides, kilometers)
	print("distance for side", sides, "is", distance, "kilometers", kilometers)
	if kilometers >= kilometers_endgame then
		wesnoth.wml_actions.kill {
			side = enemy,
			animate = false,
			fire_event = true,
			canrecruit = true,
		}
	end
	wesnoth.wml_actions.label {
		text = "kilometers run:\n" .. kilometers,
		x = border + (is_left and math.floor(width / 4) or math.floor(width * 3 / 4)),
		y = height,
	}
	local copy_strength = distance >= 5 and 100
		or distance == 4 and 80
		or distance == 3 and 60
		or distance == 2 and 40
		or distance == 1 and 20
		or 10
	return copy_strength
end

local function turn_refresh()
	if wesnoth.current.turn % wave_length == 1 then
		if wesnoth.current.side == 1 then
			local scrolled_left = scroll_down(human_side1 .. "," .. ai_side1, true, human_side2)
			local scrolled_right = scroll_down(human_side2 .. "," .. ai_side2, false, human_side1)
			copy_units(human_side1, ai_side2, scrolled_right)
			copy_units(human_side2, ai_side1, scrolled_left)
			wesnoth.wml_actions.redraw {}
		end
	end
	afterlife.unpetrify_units()
	local next_wave_turn = wesnoth.current.turn
		- (wesnoth.current.turn - 2) % wave_length
		+ wave_length - 1
	wesnoth.wml_actions.label {
		x = border + half_width,
		y = 2,
		text = string.format("<span color='#FFFFFF'>Next wave:\n    turn %s</span>", next_wave_turn)
	}
end

for i, color in ipairs {
	-- "0,255,0",
	"85,255,0", "170,255,0", "255,255,0",
	"255,170,0", "255,85,0", "255,0,0"
} do
	wesnoth.wml_actions.label {
		x = border + half_width,
		y = height - i + 1,
		color = color,
		text = math.max(10, i * 20 - 20) .. "%",
	}
end
print("active mods:", wesnoth.game_config.mp_settings.active_mods)
wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. "
	.. "Name is \"Afterlife\".")


afterlife.turn_refresh = turn_refresh

function aftfill() -- TODO
	scroll_terrain(false, height - 1)
	scroll_terrain(true, height - 1)
	wesnoth.wml_actions.redraw {}
end

-- >>
