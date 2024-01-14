-- << early_init_once | afterlife_scenario

afterlife = {}
local addon = afterlife

---This function is a work-around for https://github.com/wesnoth/wesnoth/issues/8157
---Once that issue is solved, this code can be removed.
---
---@param filename string
function addon.is_loaded(filename)
	local result = addon[filename]
	addon[filename] = true
	return result
end

-- >>
