# test_music_system.gd
# Technical Rationale: Focused validation for the V1 music layer. Runs fully
# headless and never depends on real music assets: streams are tiny generated
# in-memory WAV fixtures (ephemeral test doubles, not production files).
# Timing-sensitive windows wait on real time (SceneTreeTimer), since headless
# frame rate is uncapped and tweens/mixing advance on wall clock, not frames.
# Natural-finish behavior is simulated deterministically exactly as the engine
# delivers it: the voice reaches its end first (stop), THEN the generation-
# guarded finished handler runs.
# Covers: initialization, Music-bus availability, all six states, graceful
# behavior for unregistered states, play/stop/pause/resume, fade in/out,
# crossfade voice lifecycle (exactly two voices, no permanent duplicates),
# specific/random variant selection, config-driven looping vs one-shot result
# tracks, current track/state queries, Music bus volume isolation, Master bus
# untouched, and signal emission.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _state_changes: int = 0
var _track_starts: int = 0

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

func _make_stream(duration_s: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(duration_s * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _make_track(id: StringName, stream: AudioStream, loop: bool, volume_db: float = 0.0) -> MusicTrack:
	var t := MusicTrack.new()
	t.id = id
	t.stream = stream
	t.loop = loop
	t.volume_db = volume_db
	return t

func _count_voices(node: Node) -> int:
	var n: int = 0
	for child in node.get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			n += 1
	return n

func _count_playing_voices(node: Node) -> int:
	var n: int = 0
	for child in node.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			n += 1
	return n

func _master_bus_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))

func _run() -> void:
	await _wait_s(0.05)
	var am: Variant = root.get_node("/root/AudioManager")
	var master_db_at_start: float = _master_bus_db()
	# Long fixtures outlive every fade window so playback state reflects the
	# transition under test rather than accidental stream exhaustion.
	var long_stream := _make_stream(30.0)

	# ── A. INITIALIZATION ──────────────────────────────────────────────
	var c := MusicController.new()
	root.add_child(c)
	await _wait_s(0.05)
	c.state_changed.connect(func(_s: int) -> void: _state_changes += 1)
	c.track_started.connect(func(_t: MusicTrack) -> void: _track_starts += 1)
	_check(c.get_current_state() == MusicController.State.NONE, "A1 initial state is NONE")
	_check(c.get_current_track() == null, "A2 no current track initially")
	_check(not c.is_playing(), "A3 not playing initially")
	_check(not c.is_paused(), "A4 not paused initially")
	_check(_count_voices(c) == 2, "A5 exactly two reusable music voices")
	_check(am.has_bus(&"Music"), "A6 Music bus available in layout")
	_check(c._audio_manager != null, "A7 controller bound to AudioManager")

	# ── B. UNREGISTERED STATE IS GRACEFUL + REGISTRATION ─────────────
	_check(c.set_state(MusicController.State.VICTORY, 0.0) == false, "B1 unregistered state rejected")
	_check(c.get_current_state() == MusicController.State.NONE, "B2 state unchanged on rejection")
	_check(not c.is_playing(), "B3 nothing started on rejection")
	c.register_track(MusicController.State.INTRO, _make_track(&"intro_a", long_stream, true))
	c.register_track(MusicController.State.COMBAT, _make_track(&"combat_a", long_stream.duplicate(), true, -3.0))
	c.register_track(MusicController.State.COMBAT, _make_track(&"combat_b", long_stream.duplicate(), true, -6.0))
	c.register_track(MusicController.State.TRANSITION, _make_track(&"transition_a", long_stream.duplicate(), false))
	c.register_track(MusicController.State.VICTORY, _make_track(&"victory_a", long_stream.duplicate(), false))
	c.register_track(MusicController.State.DEFEAT, _make_track(&"defeat_a", long_stream.duplicate(), false))
	_check(c.get_registered_count(MusicController.State.INTRO) == 1 \
		and c.get_registered_count(MusicController.State.COMBAT) == 2 \
		and c.get_registered_count(MusicController.State.TRANSITION) == 1 \
		and c.get_registered_count(MusicController.State.VICTORY) == 1 \
		and c.get_registered_count(MusicController.State.DEFEAT) == 1,
		"B4 registration counts correct (variants supported)")

	# ── C. INSTANT PLAYBACK / STOP / PAUSE / RESUME ───────────────────
	_check(c.set_state(MusicController.State.INTRO, 0.0), "C1 set_state(INTRO) accepted")
	_check(c.get_current_state() == MusicController.State.INTRO, "C2 state is INTRO")
	_check(c.is_playing(), "C3 INTRO track playing")
	_check(c.get_current_track().id == &"intro_a", "C4 current track query correct")
	_check_abs(c._active_voice.volume_db, 0.0, 0.001, "C5 instant path applies target volume")
	_check(c._loop_current, "C6 looping honored from track config")
	_check(c.play_track(null, 0.0) == false, "C7 null track rejected")
	_check(c.play_track(_make_track(&"bad", null, false), 0.0) == false, "C8 stream-less track rejected")
	_check(c.pause_music(), "C9 pause accepted while playing")
	_check(c.is_paused(), "C10 paused flag set")
	_check(not c.is_playing(), "C11 not 'playing' while paused")
	_check(c.resume_music(), "C12 resume accepted")
	_check(not c.is_paused(), "C13 paused flag cleared")
	_check(c.is_playing(), "C14 playing again after resume")
	_check(c.stop_music(), "C15 explicit stop accepted")
	_check(not c.is_playing(), "C16 stopped")
	_check(c.get_current_state() == MusicController.State.NONE, "C17 explicit stop resets state to NONE")
	_check(c.get_current_track() == null, "C18 explicit stop clears track")
	_check(c.pause_music() == false, "C19 pause refused when idle")
	_check(_count_voices(c) == 2, "C20 voice pool stable after stop")

	# ── D. FADE IN / FADE OUT ─────────────────────────────────────────
	_check(c.set_state(MusicController.State.TRANSITION, 0.3), "D1 set_state(TRANSITION) with fade accepted")
	_check(c._active_voice.volume_db == MusicController.FADE_FLOOR_DB, "D2 fade-in starts from silence floor")
	await _wait_s(0.5)
	_check(c.is_playing(), "D3 transition track playing after fade-in window")
	_check_abs(c._active_voice.volume_db, 0.0, 0.5, "D4 fade-in reaches track target volume")
	_check(c.get_current_state() == MusicController.State.TRANSITION, "D5 state is TRANSITION")
	_check(c.fade_out(0.25), "D6 fade_out accepted")
	_check(c.get_current_state() == MusicController.State.NONE, "D7 fade_out ends in NONE immediately")
	await _wait_s(0.45)
	_check(not c.is_playing(), "D8 faded out completely")
	_check(c._active_voice.volume_db == MusicController.FADE_FLOOR_DB, "D9 voice parked at silence floor")
	_check(c._active_voice.stream == null and c._fadeout_voice.stream == null, "D10 voices released after fade-out")

	# ── E. CROSSFADE ──────────────────────────────────────────────────
	_check(c.set_state(MusicController.State.COMBAT, 0.05, 0), "E1 combat variant 0 selected explicitly")
	await _wait_s(0.25)
	_check(c.is_playing() and c.get_current_track().id == &"combat_a", "E2 combat_a active")
	_check(c.set_state(MusicController.State.TRANSITION, 0.3), "E3 crossfade requested mid-playback")
	_check(_count_playing_voices(c) == 2, "E4 both voices audible during crossfade (no abrupt cut)")
	_check(c.get_current_track().id == &"transition_a", "E5 new track is active immediately")
	await _wait_s(0.6)
	_check(_count_playing_voices(c) == 1, "E6 exactly one voice after crossfade completes")
	_check(c._fadeout_voice.stream == null and not c._fadeout_voice.playing, "E7 outgoing voice stopped and released")
	_check(c.get_current_state() == MusicController.State.TRANSITION, "E8 state follows crossfade target")
	_check(_count_voices(c) == 2, "E9 no permanent duplicate players created")

	# ── F. VARIANT SELECTION ──────────────────────────────────────────
	_check(c.set_state(MusicController.State.COMBAT, 0.0, 1), "F1 specific variant index accepted")
	_check(c.get_current_track().id == &"combat_b", "F2 variant 1 is combat_b")
	_check_abs(c._active_voice.volume_db, -6.0, 0.001, "F3 per-track volume applied")
	var valid_random: bool = true
	for _i: int in range(3):
		c.set_state(MusicController.State.COMBAT, 0.0)
		var picked_id: StringName = c.get_current_track().id
		if picked_id != &"combat_a" and picked_id != &"combat_b":
			valid_random = false
	_check(valid_random, "F4 random selection always yields a registered variant")

	# ── G. LOOPING CONFIGURATION (engine-style finish: end, then event) ─
	_check(c.set_state(MusicController.State.INTRO, 0.0), "G1 intro (loop=true) started")
	c._active_voice.stop()
	c._on_voice_finished(c._active_voice)
	_check(c.is_playing(), "G2 looped intro restarts after natural finish")
	_check(c.get_current_state() == MusicController.State.INTRO, "G3 state persists across loop restart")
	_check(c.get_current_track().id == &"intro_a", "G4 loop restart keeps current track")
	_check(c.set_state(MusicController.State.VICTORY, 0.0), "G5 victory (loop=false) started")
	c._active_voice.stop()
	c._on_voice_finished(c._active_voice)
	_check(not c.is_playing(), "G6 result track does NOT auto-restart")
	_check(c.get_current_state() == MusicController.State.VICTORY, "G7 state KEPT after natural result finish")
	_check(c.get_current_track().id == &"victory_a", "G8 finished result track remains queryable")
	_check(c._loop_current == false, "G9 result track loop flag false")
	_check(c.set_state(MusicController.State.DEFEAT, 0.0), "G10 defeat (loop=false) started")
	c._active_voice.stop()
	c._on_voice_finished(c._active_voice)
	_check(not c.is_playing(), "G11 non-loop defeat does not auto-restart")
	_check(c.get_current_state() == MusicController.State.DEFEAT, "G12 defeat state kept after finish")
	_check(c.stop_music(), "G13 caller can stop explicitly after result")
	_check(c.get_current_state() == MusicController.State.NONE, "G14 explicit stop resets to NONE")

	# ── H. MUSIC VOLUME ISOLATION ─────────────────────────────────────
	_check(c.set_music_volume(0.25), "H1 music volume API accepted")
	_check_abs(c.get_music_volume(), 0.25, 0.001, "H2 Music bus reflects requested linear volume")
	_check(_master_bus_db() == master_db_at_start, "H3 Master bus untouched by music volume")
	_check(c.set_music_volume(1.0), "H4 music volume restored")
	_check_abs(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), 0.0, 0.01,
		"H5 Music bus back at unity gain")
	_check(_master_bus_db() == master_db_at_start, "H6 Master bus identical to pre-test value")

	# ── I. SIGNALS + CLEANUP ──────────────────────────────────────────
	_check(_state_changes >= 3, "I1 state_changed emitted")
	_check(_track_starts >= 3, "I2 track_started emitted")
	_check(am.is_music_playing() == false, "I3 AudioManager legacy music channel untouched")
	c.queue_free()
	await _wait_s(0.05)
	_check(not is_instance_valid(c), "I4 controller freed cleanly")

	print("== RESULT: %d passed, %d failed ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
