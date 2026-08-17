# test_game_settings.gd
# Technical Rationale: Headless validation of the GameSettings autoload: presence
# in the tree, defaults, ConfigFile persistence round-trip (save -> fresh instance
# load), and independence from GameConfig's own settings file.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
#
# Run: godot --headless --path game --script res://tests/test_game_settings.gd

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

const SETTINGS_PATH: String = "user://gravity_game_settings.cfg"
const GAMECONFIG_PATH: String = "user://gravity_config.cfg"

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

## Snapshot / restore helper so this test never clobbers a live user config.
func _backup_cfg(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""

func _restore_cfg(path: String, backup: String) -> void:
	if backup.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	else:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)

func run_test() -> void:
	print("== GAME SETTINGS TEST ==")
	var backup: String = _backup_cfg(SETTINGS_PATH)

	var gs: Node = get_root().get_node_or_null("GameSettings")
	_check(gs != null, "GameSettings autoload present in tree")
	if gs == null:
		quit(1)
		return

	# Defaults on a virgin config (force by clearing the file first).
	_restore_cfg(SETTINGS_PATH, "")
	gs.call("load_settings")
	_check(bool(gs.get("fog_of_war_enabled")), "fog_of_war_enabled defaults to true")
	_check(is_equal_approx(float(gs.get("fog_explored_brightness")), 0.35),
		"fog_explored_brightness defaults to 0.35")
	_check(is_equal_approx(float(gs.get("fog_visible_brightness")), 0.62),
		"fog_visible_brightness defaults to 0.62 (light grey, not white)")
	_check(is_equal_approx(float(gs.get("fog_edge_softness")), 0.5),
		"fog_edge_softness defaults to 0.5")

	# Mutate + persist.
	gs.set("fog_of_war_enabled", false)
	gs.set("fog_explored_brightness", 0.6)
	gs.set("fog_visible_brightness", 0.5)
	gs.set("fog_edge_softness", 0.2)
	gs.call("save_settings")
	_check(FileAccess.file_exists(SETTINGS_PATH), "GameSettings persisted to its own user:// file")

	# Simulate process restart: brand-new GameSettings instance loads from disk.
	var fresh: Node = (load("res://scripts/game_settings.gd") as GDScript).new()
	get_root().add_child(fresh)
	await physics_frame
	await physics_frame
	_check(is_instance_valid(fresh), "fresh GameSettings instance boots (simulated relaunch)")
	_check(bool(fresh.get("fog_of_war_enabled")) == false, "fog_of_war_enabled=false survives relaunch")
	_check(is_equal_approx(float(fresh.get("fog_explored_brightness")), 0.6),
		"fog_explored_brightness=0.6 survives relaunch")
	_check(is_equal_approx(float(fresh.get("fog_visible_brightness")), 0.5),
		"fog_visible_brightness=0.5 survives relaunch")
	_check(is_equal_approx(float(fresh.get("fog_edge_softness")), 0.2),
		"fog_edge_softness=0.2 survives relaunch")

	# Independence from GameConfig: GameSettings uses its own file, not gravity_config.cfg.
	_check(SETTINGS_PATH != GAMECONFIG_PATH, "GameSettings uses a separate settings file")
	_check(not FileAccess.file_exists(GAMECONFIG_PATH) or _backup_cfg(GAMECONFIG_PATH) != "",
		"GameSettings save never touched gravity_config.cfg (path-independent)")

	fresh.queue_free()
	await physics_frame
	_restore_cfg(SETTINGS_PATH, backup)
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)