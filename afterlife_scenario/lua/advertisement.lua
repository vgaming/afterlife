-- << mirrorfaction_advertisement

local wesnoth = wesnoth
local tostring = tostring

local script_arguments = ...
local remote_version = tostring(script_arguments.remote_version)

if not wesnoth.have_file("~add-ons/afterlife_scenario/target/version.txt") then
	wesnoth.message("Afterlife", "If you('ll) like the map, feel free to download it. Name is \"Afterlife\".")
else
	local local_version = wesnoth.read_file("~add-ons/afterlife_scenario/target/version.txt")
	if wesnoth.compare_versions(remote_version, ">", local_version) then
		wesnoth.wml_actions.message {
			caption = "Afterlife",
			message = [[🠉🠉🠉 Please upgrade your Afterlife version. 🠉🠉🠉

(You can do that after the game)]],
			image = "misc/blank-hex.png~BLIT(units/human-loyalists/spearman.png~CROP(20,0,31,72)~FL())~BLIT(units/human-loyalists/spearman.png~CROP(20,0,31,72)~GS(),36,0)",
		}
	end
end

-- >>
