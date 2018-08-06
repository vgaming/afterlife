-- << afterlife_advertisement

local wesnoth = wesnoth
local tostring = tostring

local script_arguments = ...
local remote_version = tostring(script_arguments.remote_version)
local filename = "~add-ons/afterlife_scenario/target/version.txt"

local side = wesnoth.sides[wesnoth.current.side]
if not side.is_local and side.controller == "human" then
	if not wesnoth.have_file(filename) then
		wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. Name is \"Afterlife\".")
	else
		local local_version = wesnoth.read_file(filename)
		if wesnoth.compare_versions(remote_version, ">", local_version) then
			wesnoth.wml_actions.message {
				caption = "Afterlife",
				message = "🠉🠉🠉 Please upgrade your Afterlife version. 🠉🠉🠉"
					.. "\n\n"
					.. local_version .. " -> " .. remote_version
					.. "(You can do that after the game)",
				image = "misc/blank-hex.png~BLIT(units/human-loyalists/spearman.png~CROP(20,0,31,72)~FL())~BLIT(units/human-loyalists/spearman.png~CROP(20,0,31,72)~GS(),36,0)",
			}
		end
	end
	wesnoth.wml_actions.remove_event { id = "afterlife_ad" }
end

-- >>
