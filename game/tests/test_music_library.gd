# test_music_library.gd
# Technical Rationale: Focused validation for the MusicLibrary wiring between
# the REAL project music assets and MusicController (complements, never
# replaces, the fixture-based test_music_system.gd).
# Proves: DRAW state exists; the six canonical directories are recognized;
# real project audio is discovered and becomes valid registered variants;
# category loop policy (intro/combat loop, result categories one-shot);
# unrelated files (.gitkeep/.import/...) are filtered out; per-state counts
# match an independent directory scan so empty categories do not fail; and
# at least one REAL imported MP3 completes the playback chain through an
# actual AudioStreamPlayer voice on the Music bus.
extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: " + label)
	else:
		_failed += 1
		print("FAIL: " + label)

func _check_abs(value: float, expected: float, eps: float, label: String) -> void:
	_check(absf(value - expected) <= eps, label)

func _wait_s(seconds: float) -> void:
	await create_timer(seconds).timeout

func _disk_count(dir_name: String) -> int:
	var d := DirAccess.open("res://audio/music".path_join(dir_name))
	if d == null:
		return -1
	var n: int = 0
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not d.current_is_dir() and MusicLibrary.is_supported_audio_file(entry):
			n += 1
		entry = d.get_next()
	d.list_dir_end()
	return n

func _run() -> void:
	await _wait_s(0.05)

	# ── K. STATE MODEL + CONTRACT ─────────────────────────────────────
	_check(MusicController.State.DRAW == MusicController.State.DEFEAT + 1 \
		and MusicController.State.DRAW != MusicController.State.NONE,
		"K1 DRAW state exists and extends the model")
	var dir_names: Array = []
	for state_value: int in MusicLibrary.STATE_DIRS:
		dir_names.append(MusicLibrary.STATE_DIRS[state_value])
	dir_names.sort()
	_check(str(dir_names) == str(["combat", "defeat", "draw", "intro", "transition", "victory"]),
		"K2 six canonical directories mapped (draw included)")
	_check(MusicLibrary.is_supported_audio_file("a.mp3") and MusicLibrary.is_supported_audio_file("b.ogg")
		and MusicLibrary.is_supported_audio_file("c.wav") and MusicLibrary.is_supported_audio_file("D.MP3"),
		"K3 supported formats accepted (case-insensitive)")
	_check(not MusicLibrary.is_supported_audio_file(".gitkeep")
		and not MusicLibrary.is_supported_audio_file("x.mp3.import")
		and not MusicLibrary.is_supported_audio_file("y.tmp")
		and not MusicLibrary.is_supported_audio_file("z.png"),
		"K4 unrelated extensions rejected")

	# ── L. DISCOVERY + REGISTRATION AGAINST REAL ASSETS ───────────────
	var c := MusicController.new()
	root.add_child(c)
	await _wait_s(0.05)
	var lib := MusicLibrary.new()
	var total: int = lib.populate(c)
	_check(total > 0, "L1 real music discovered and registered (%d tracks)" % total)
	var all_match: bool = true
	for state_value: int in MusicLibrary.STATE_DIRS:
		var dir_name: String = MusicLibrary.STATE_DIRS[state_value]
		if lib.get_registered_count_for(state_value) != maxi(_disk_count(dir_name), 0):
			all_match = false
			print("  mismatch in %s: lib=%d disk=%d" % [dir_name,
				lib.get_registered_count_for(state_value), _disk_count(dir_name)])
	_check(all_match, "L5 per-state registration matches independent disk scan")
	var controller_match: bool = true
	for state_value: int in MusicLibrary.STATE_DIRS:
		if c.get_registered_count(state_value as MusicController.State) != lib.get_registered_count_for(state_value):
			controller_match = false
	_check(controller_match, "L6 MusicController received every library track")

	# Streams valid + ids clean.
	var streams_ok: bool = true
	var ids_clean: bool = true
	for state_value: int in MusicLibrary.STATE_DIRS:
		for t: MusicTrack in lib.tracks_by_state[state_value]:
			if t.stream == null or not (t.stream is AudioStream):
				streams_ok = false
			var id_text := String(t.id)
			if id_text == "" or id_text.contains(".") or id_text.begins_with("."):
				ids_clean = false
	_check(streams_ok, "L7 every registered track carries a valid AudioStream")
	_check(ids_clean, "L8 no junk/unrelated file became a track id")
	_check(lib.errors.is_empty(), "L9 no load/directory errors recorded")

	# ── M. CATEGORY LOOP POLICY ON REAL TRACKS ────────────────────────
	var loops_ok := true
	for t: MusicTrack in lib.tracks_by_state[MusicController.State.INTRO]:
		if t.loop != true: loops_ok = false
	for t: MusicTrack in lib.tracks_by_state[MusicController.State.COMBAT]:
		if t.loop != true: loops_ok = false
	_check(loops_ok, "M1 INTRO+COMBAT real tracks registered with loop=true")
	var oneshot_ok := true
	for state_value: int in [MusicController.State.TRANSITION, MusicController.State.VICTORY,
			MusicController.State.DEFEAT, MusicController.State.DRAW]:
		for t: MusicTrack in lib.tracks_by_state[state_value]:
			if t.loop != false: oneshot_ok = false
	_check(oneshot_ok, "M2 TRANSITION/VICTORY/DEFEAT/DRAW real tracks are one-shot")
	_check(absf(float((lib.tracks_by_state[MusicController.State.INTRO][0] as MusicTrack).volume_db)) < 0.001,
		"M3 default neutral volume applied")

	# ── N. REAL PLAYBACK CHAIN (MP3 -> ... -> Music bus) ──────────────
	_check(c.set_state(MusicController.State.COMBAT, 0.1), "N1 real COMBAT track started via set_state")
	await _wait_s(0.45)
	var current: MusicTrack = c.get_current_track()
	_check(c.is_playing(), "N2 real MP3 audible through controller voice")
	_check(current != null and current.stream.get_class() == "AudioStreamMP3",
		"N3 chain link verified: imported MP3 loads as AudioStreamMP3")
	_check(c._active_voice.bus == &"Music", "N4 chain link verified: voice routed to Music bus")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")) == &"Master",
		"N5 chain link verified: Music bus sends to Master")
	_check(c.fade_out(0.15), "N6 fade_out over real track accepted")
	await _wait_s(0.35)
	_check(not c.is_playing(), "N7 real track faded out cleanly")

	# ── O. NEW DRAW STATE SEMANTICS WITH REAL ASSET ───────────────────
	_check(c.set_state(MusicController.State.DRAW, 0.0), "O1 real DRAW track started")
	var draw_track: MusicTrack = c.get_current_track()
	c._active_voice.stop()
	c._on_voice_finished(c._active_voice)
	_check(not c.is_playing(), "O2 DRAW track does not auto-restart (one-shot)")
	_check(c.get_current_state() == MusicController.State.DRAW, "O3 DRAW state kept after natural completion")
	_check(c.get_current_track() == draw_track, "O4 finished DRAW track remains queryable")
	_check(c.stop_music(), "O5 explicit stop from DRAW works")
	_check(c.get_current_state() == MusicController.State.NONE, "O6 stop resets to NONE")

	# ── P. EXISTING STATES UNCHANGED (spot checks) ────────────────────
	_check(c.set_state(MusicController.State.VICTORY, 0.0)
		and c.get_current_state() == MusicController.State.VICTORY,
		"P1 VICTORY semantics untouched by DRAW addition")
	c._active_voice.stop()
	c._on_voice_finished(c._active_voice)
	_check(c.get_current_state() == MusicController.State.VICTORY and not c.is_playing(),
		"P2 VICTORY still one-shot with state kept")
	c.stop_music()

	c.queue_free()
	await _wait_s(0.05)

	print("== RESULT: %d passed, %d failed ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
