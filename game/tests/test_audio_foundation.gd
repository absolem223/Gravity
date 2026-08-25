# test_audio_foundation.gd
# Technical Rationale: Focused regression suite for the V1 audio foundation:
# bus layout load (Master > SFX/UI/Environment/Music), AudioManager autoload
# wiring, non-positional/UI/music playback channels, native 3D one-shot spawn,
# linear bus volume/mute API, and the Master-volume authority contract
# (GameConfig owns Master; AudioManager must not touch it).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

## Generates a short silent WAV stream (~0.1 s) for playback-state assertions
## without shipping any binary asset.
func _make_tone() -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4410)
	wav.data = bytes
	return wav

func run_test() -> void:
	print("== AUDIO FOUNDATION TEST ==")

	# --- [1] Bus layout ---
	var expected_buses: Array[StringName] = [&"Master", &"SFX", &"UI", &"Environment", &"Music"]
	_check(AudioServer.bus_count == expected_buses.size(),
		"bus layout loaded with %d buses (got %d)" % [expected_buses.size(), AudioServer.bus_count])
	var names_ok: bool = true
	for i: int in range(expected_buses.size()):
		if i >= AudioServer.bus_count or StringName(AudioServer.get_bus_name(i)) != expected_buses[i]:
			names_ok = false
	_check(names_ok, "buses are exactly Master,SFX,UI,Environment,Music in order")
	for bus_name: StringName in [&"SFX", &"UI", &"Environment", &"Music"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		_check(idx > 0 and AudioServer.get_bus_send(idx) == StringName("Master"),
			"bus '%s' routes to Master" % String(bus_name))

	# --- [2] Autoload wiring ---
	var am: Node = get_root().get_node_or_null(^"/root/AudioManager")
	_check(am != null, "AudioManager autoload present under /root")
	if am == null:
		print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
		quit(1)
		return

	# --- [3] Non-positional SFX pool ---
	var tone: AudioStreamWAV = _make_tone()
	am.play_sfx(tone, 0.0, 1.0)
	var any_playing: bool = false
	for child: Node in am.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing \
				and (child as AudioStreamPlayer).bus == &"SFX":
			any_playing = true
			break
	_check(any_playing, "play_sfx activates a pooled SFX-bus voice")
	am.stop_all_sfx()
	var all_stopped: bool = true
	for child: Node in am.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			all_stopped = false
			break
	_check(all_stopped, "stop_all_sfx silences every pooled voice (music unaffected path)")

	# --- [4] UI channel ---
	am.play_ui_sound(tone)
	_check(am._ui_player.playing and am._ui_player.bus == &"UI",
		"play_ui_sound uses the dedicated UI-bus channel")
	am.stop_ui_sound()
	_check(not am._ui_player.playing, "stop_ui_sound stops the UI channel")

	# --- [5] Music channel ---
	am.play_music(tone)
	_check(am.is_music_playing() and am._music_player.bus == &"Music",
		"play_music uses the dedicated Music-bus channel")
	am.play_music(tone)
	_check(am._music_player.playing, "re-play_music with same stream keeps music alive")
	am.stop_music()
	_check(not am.is_music_playing(), "stop_music halts music playback")

	# --- [6] Spatial foundation ---
	var p3d: AudioStreamPlayer3D = am.play_sfx_3d(tone, Vector3(3.0, 0.0, -4.0))
	_check(p3d != null and p3d is AudioStreamPlayer3D, "play_sfx_3d spawns an AudioStreamPlayer3D")
	if p3d != null:
		_check(p3d.bus == &"SFX", "3D one-shot routes to the SFX bus")
		_check(p3d.position.distance_to(Vector3(3.0, 0.0, -4.0)) < 0.001,
			"3D one-shot placed at the requested world position")
		p3d.stop()
		p3d.queue_free()
	await process_frame
	_check(not is_instance_valid(p3d), "transient 3D player cleanup works")

	# --- [7] Bus volume/mute API ---
	_check(bool(am.has_bus(&"SFX")) and not bool(am.has_bus(&"Nonexistent")),
		"has_bus distinguishes existing vs missing buses")
	var ok_set: bool = am.set_bus_volume_linear(&"SFX", 0.5)
	var read_back: float = am.get_bus_volume_linear(&"SFX")
	_check(ok_set and absf(read_back - 0.5) < 0.01,
		"set/get_bus_volume_linear round-trip on SFX (%.3f)" % read_back)
	am.set_bus_muted(&"Environment", true)
	var muted_ok: bool = am.is_bus_muted(&"Environment") and not am.is_bus_muted(&"SFX")
	am.set_bus_muted(&"Environment", false)
	_check(muted_ok and not am.is_bus_muted(&"Environment"), "mute round-trip isolated per bus")
	_check(not bool(am.set_bus_volume_linear(&"Nonexistent", 0.5)),
		"volume writes to a missing bus fail gracefully")

	# --- [8] Master-volume authority contract ---
	var master_idx: int = AudioServer.get_bus_index(&"Master")
	var before_db: float = AudioServer.get_bus_volume_db(master_idx)
	am.set_bus_volume_linear(&"UI", 0.3)
	var after_db: float = AudioServer.get_bus_volume_db(master_idx)
	_check(absf(before_db - after_db) < 0.0001,
		"AudioManager bus operations leave Master untouched")
	# Access GameConfig through the tree (autoload identifiers are not
	# compile-time resolvable under --script/--check-only).
	var game_config: Node = get_root().get_node_or_null(^"/root/GameConfig")
	_check(game_config != null, "GameConfig autoload present for Master authority check")
	if game_config != null:
		game_config.set("master_volume_linear", 0.25)
		game_config.call("apply_runtime_settings")
		var applied_db: float = AudioServer.get_bus_volume_db(master_idx)
		var expected_db: float = linear_to_db(0.25)
		_check(absf(applied_db - expected_db) < 0.001,
			"GameConfig remains the Master-volume authority (apply_runtime_settings)")
		game_config.set("master_volume_linear", 1.0)
		game_config.call("apply_runtime_settings")

	# Restore SFX bus to unity so other suites start from a neutral layout.
	am.set_bus_volume_linear(&"SFX", 1.0)

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
