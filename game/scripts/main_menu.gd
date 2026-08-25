# main_menu.gd
# Technical Rationale: Root scene shell (MC_MAIN applied). Installs the UIScreenStack
# router and pushes the first screen. All navigation lives in the UIScreenStack; this
# script only boots the flow. Adheres to ADR-0001 (GDScript 2.x Strict Typing).
#
# Music V1 bootstrap: the menu is the game's initial entry point, so it starts the
# INTRO music state. The controller is parented to the persistent root viewport (not
# this scene) so a single instance survives menu<->match scene swaps and the library
# is populated only once; later gameplay tasks drive further music states on this
# same controller. Diagnostics are gated behind the const below and stay OFF in normal
# builds.

class_name MainMenu
extends Control

## Flip to true only for one-off integration diagnostics; must stay false in normal runs.
const MUSIC_INTEGRATION_DIAGNOSTICS := false

var _stack: UIScreenStack = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuFactory.make_background())

	_stack = UIScreenStack.new()
	add_child(_stack)
	_stack.push(MainScreen.new())

	GameConfig.apply_runtime_settings()
	call_deferred("_start_intro_music")

## Boots the music layer exactly once (persistent controller) and, if nothing is
## currently playing, begins INTRO with a gentle fade-in. Does not touch gameplay
## states (COMBAT/VICTORY/DEFEAT/DRAW) — those are future integrations.
func _start_intro_music() -> void:
	var root_viewport := get_tree().root
	var controller := root_viewport.get_node_or_null("MusicController")
	if controller == null:
		controller = MusicController.new()
		controller.name = "MusicController"
		root_viewport.add_child(controller)
		var library := MusicLibrary.new()
		library.populate(controller)
		if MUSIC_INTEGRATION_DIAGNOSTICS:
			_diagnose(controller)
	if controller.get_current_state() != MusicController.State.INTRO:
		controller.set_state(MusicController.State.INTRO, 1.5)

func _diagnose(controller: MusicController) -> void:
	var state := controller.get_current_state()
	var track := controller.get_current_track()
	var voice := controller._active_voice
	var music_idx := AudioServer.get_bus_index(&"Music")
	print("[MUSIC-DIAG] state=%d registered_intro=%d track=%s stream=%s playing=%s bus=%s music_db=%.2f master_db=%.2f" % [
		state,
		controller.get_registered_count(MusicController.State.INTRO),
		track.id if track != null else &"",
		"AudioStream" if (track != null and track.stream != null) else "null",
		voice.playing if voice != null else false,
		voice.bus if voice != null else &"",
		AudioServer.get_bus_volume_db(music_idx),
		AudioServer.get_bus_volume_db(0),
	])
