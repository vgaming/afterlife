not_pushed_ignore=true

upload_to_wesnoth_versions=(1.14)

description() {
	cat ./afterlife_scenario/doc/about.txt
	echo -e "\nPlaying time: ~ 25 minutes."
}

addon_manager_args=("--pbl-key" "icon" "$(cat src/doc/icon.txt)")
