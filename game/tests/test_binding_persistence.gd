## binding_persistence.gd
## Headless regression: user-customized input bindings (e.g. a gamepad fire on R2
## plus a re-mapped shoulder button) survive a full relaunch cycle. Simulates
## shutdown+startup by re-instantiating the GameConfig autoload from the same
## persisted user://gravity_config.cfg and asserting the stored binding set
## round-trips unchanged (device defaults must never overwrite saved overrides).
##
## Run: godot --headless --path game --script res://tests/test_binding_persistence.gd

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

const SETTINGS_PATH: String = "user://gravity_config.cfg"

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
func _backup_cfg() -> String:
	if FileAccess.file_exists(SETTINGS_PATH):
		return FileAccess.get_file_as_string(SETTINGS_PATH)
	return ""

func _restore_cfg(backup: String) -> void:
	if backup.is_empty():
		if FileAccess.file_exists(SETTINGS_PATH):
			DirAccess.remove_absolute(SETTINGS_PATH)
	else:
		var f: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(backup)

func run_test() -> void:
	print("== BINDING PERSISTENCE TEST (relaunch round-trip) ==")
	var backup: String = _backup_cfg()

	var cfg: Node = get_root().get_node_or_null("GameConfig")
	_check(cfg != null, "GameConfig autoload present")
	if cfg == null:
		quit(1)
		return

	cfg.call("reset_slots_to_defaults")

	# Simulate a human who set P2 to a gamepad and re-mapped ability OFF L1
	# (e.g. to R2) in the bindings screen, with fire left on the R2 trigger axis.
	var p2: InputProfile = cfg.call("get_profile", 2) as InputProfile
	_check(p2 != null, "P2 profile exists")
	if p2 == null:
		quit(1)
		return
	p2.set_device(InputProfile.DeviceKind.JOYSTICK, 1)
	p2.reset_defaults()
	var r2_fire: InputEventJoypadMotion = InputEventJoypadMotion.new()
	r2_fire.axis = JOY_AXIS_TRIGGER_RIGHT
	r2_fire.axis_value = 1.0
	p2.bind_action("fire", r2_fire)
	var ability_override: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ability_override.axis = JOY_AXIS_TRIGGER_LEFT
	ability_override.axis_value = 1.0
	p2.bind_action("ability", ability_override)

	# P1 (keyboard) user also re-mapped their fire key.
	var p1: InputProfile = cfg.call("get_profile", 1) as InputProfile
	if p1 != null:
		p1.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
		p1.reset_defaults()
		var k: InputEventKey = InputEventKey.new()
		k.keycode = KEY_G
		p1.bind_action("fire", k)

	cfg.call("save_settings")
	_check(FileAccess.file_exists(SETTINGS_PATH), "settings persisted to user://gravity_config.cfg")

	# ── Simulate process restart: brand-new GameConfig instance loads from disk ──
	var fresh: Node = (load("res://scripts/game_config.gd") as GDScript).new()
	get_root().add_child(fresh)
	await physics_frame
	await physics_frame
	_check(is_instance_valid(fresh), "fresh GameConfig instance boots (simulated relaunch)")

	var np2: InputProfile = fresh.call("get_profile", 2) as InputProfile
	_check(np2 != null, "fresh P2 profile restored")
	if np2 == null:
		fresh.queue_free()
		_restore_cfg(backup)
		quit(1)
		return

	_check(np2.device_kind == InputProfile.DeviceKind.JOYSTICK, "P2 survives relaunch as a joystick profile (device persisted)")
	_check(np2.joystick_index == 1, "P2 joystick slot 1 persisted")

	var fire_ev: InputEvent = np2.get_events("fire")[0] if not np2.get_events("fire").is_empty() else null
	_check(fire_ev is InputEventJoypadMotion, "P2 fire still a joystick axis after relaunch (not clobbered to keyboard)")
	if fire_ev is InputEventJoypadMotion:
		_check((fire_ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT, "P2 fire axis R2 restored exactly")
		_check((fire_ev as InputEventJoypadMotion).axis_value >= 1.0, "P2 fire trigger polarity restored")

	var ab_ev: InputEvent = np2.get_events("ability")[0] if not np2.get_events("ability").is_empty() else null
	_check(ab_ev is InputEventJoypadMotion and (ab_ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT,
		"P2 ability override (LT) persisted exactly")

	var np1: InputProfile = fresh.call("get_profile", 1) as InputProfile
	_check(np1 != null, "fresh P1 profile restored")
	if np1 != null:
		_check(np1.is_keyboard(), "P1 survives relaunch as keyboard profile")
		var k1: InputEvent = np1.get_events("fire")[0] if not np1.get_events("fire").is_empty() else null
		_check(k1 is InputEventKey and (k1 as InputEventKey).keycode == KEY_G, "P1 fire key override (G) persisted exactly")

	# No device-default pass is allowed to wipe the customized bindings on relaunch.
	_check(fresh.call("get_profile", 2).get_events("fire").size() == 1, "saved fire binding not duplicated by defaults on relaunch")
	_check(fresh.call("get_profile", 2).get_events("ability").size() == 1, "saved ability binding not duplicated by defaults on relaunch")

	fresh.queue_free()
	await physics_frame
	_restore_cfg(backup)
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)