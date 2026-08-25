# music_controller.gd
# Technical Rationale: Dedicated music playback/state layer on top of the
# existing audio architecture. This is NOT a second global system and NOT an
# autoload: it is an instanced Node (future menu/match integration will own
# it) that routes everything through the Music -> Master bus path. Playback
# uses two reusable AudioStreamPlayer voices for crossfading; no permanently
# growing player pool exists and the outgoing voice is stopped/cleared as
# soon as its fade completes.
#
# State model is explicit (NONE/INTRO/COMBAT/TRANSITION/VICTORY/DEFEAT/DRAW)
# but deliberately decoupled from MatchManager/gameplay: states are driven
# programmatically for now; the future layer will map match state -> music
# state -> this controller. DRAW belongs to the result family (one-shot by
# default, state kept after natural completion) like VICTORY and DEFEAT.
#
# Looping is configuration-driven per MusicTrack and implemented with a
# generation-guarded `finished` handler that restarts the active voice, so it
# works uniformly for any stream type without mutating shared imported
# stream resources. Natural finish of non-looping tracks (victory/defeat/
# transition) keeps the current state and track queryable; only explicit
# stop/set_state(NONE) resets the state to NONE.
#
# Volume ownership: Master stays exclusively with GameConfig. The optional
# music volume API here affects ONLY the Music bus by delegating to the
# AudioManager bus helpers.
class_name MusicController
extends Node

## Emitted whenever the logical music state changes (including to NONE).
signal state_changed(new_state: int)
## Emitted when a track actually starts (play, crossfade-in, or loop switch).
signal track_started(track: MusicTrack)

enum State { NONE, INTRO, COMBAT, TRANSITION, VICTORY, DEFEAT, DRAW }

## Bus from res://default_bus_layout.tres that ALL music output must use.
const BUS_MUSIC: StringName = &"Music"
## Practical silence floor used as the start/end point of every ramp.
const FADE_FLOOR_DB: float = -60.0

var _tracks: Dictionary = {}
var _current_state: State = State.NONE
var _current_track: MusicTrack = null
var _loop_current: bool = false
var _paused: bool = false
## Incremented on every new playback/stop request; guards stale callbacks
## (late `finished` events or tween completions from superseded transitions).
var _generation: int = 0
## Voice holding the currently audible track.
var _active_voice: AudioStreamPlayer = null
## Second voice dedicated to fading out during crossfades.
var _fadeout_voice: AudioStreamPlayer = null
var _tween: Tween = null
var _audio_manager: Node = null

func _ready() -> void:
	# Keep fades/music alive while the tree is paused (menus/pause screens).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Runtime lookup instead of a compile-time autoload identifier so this
	# script still parses under --check-only --script (project convention).
	_audio_manager = get_node_or_null(^"/root/AudioManager")
	if _audio_manager == null:
		push_warning("MusicController: AudioManager autoload not found; bus-volume API disabled.")
	_active_voice = _create_voice()
	_fadeout_voice = _create_voice()

## ──────────────────────────────────────────────
## TRACK REGISTRATION
## ──────────────────────────────────────────────

## Registers a track variant for a state. Several tracks per state are
## allowed; selection picks one of them (specific index or random).
func register_track(state: State, track: MusicTrack) -> void:
	if track == null:
		return
	var key: int = int(state)
	if not _tracks.has(key):
		_tracks[key] = []
	var pool: Array = _tracks[key]
	pool.append(track)

func clear_tracks(state: State) -> void:
	_tracks.erase(int(state))

func has_tracks_for(state: State) -> bool:
	return _tracks.has(int(state)) and not (_tracks[int(state)] as Array).is_empty()

func get_registered_count(state: State) -> int:
	if not _tracks.has(int(state)):
		return 0
	return (_tracks[int(state)] as Array).size()

## ──────────────────────────────────────────────
## PLAYBACK API
## ──────────────────────────────────────────────

## Plays one specific track directly (low-level). Does NOT change the logical
## state; use set_state() for state-driven playback. fade_duration > 0 fades
## in from silence (and crossfades out whatever is playing); 0 switches hard.
func play_track(track: MusicTrack, fade_duration: float = 1.0) -> bool:
	if track == null or track.stream == null:
		return false
	_kill_transition()
	_generation += 1
	var gen: int = _generation
	_loop_current = track.loop
	_paused = false
	_current_track = track
	var switching: bool = _active_voice.playing or _active_voice.stream != null
	if switching:
		# Swap roles: old active voice becomes the crossfade-out victim.
		var previous: AudioStreamPlayer = _active_voice
		_active_voice = _fadeout_voice
		_fadeout_voice = previous
	_begin_voice(_active_voice, track, gen)
	if fade_duration > 0.0 and is_inside_tree():
		_active_voice.volume_db = FADE_FLOOR_DB
		# Parallel batch: outgoing voice ramps down while the incoming one
		# ramps up simultaneously; the release callback chains after both.
		_tween = create_tween()
		_tween.set_parallel(true)
		if switching:
			_tween.tween_property(_fadeout_voice, "volume_db", FADE_FLOOR_DB, fade_duration)
		_tween.tween_property(_active_voice, "volume_db", track.volume_db, fade_duration)
		_tween.set_parallel(false)
		_tween.tween_callback(_finish_fadeout.bind(gen))
	else:
		if switching:
			_hard_stop_voice(_fadeout_voice)
		_active_voice.volume_db = track.volume_db
	track_started.emit(track)
	return true

## State-driven playback: resolves which registered variant to play, then
## plays it and records the state. Returns false without side effects if the
## state has no registered tracks (system keeps running unchanged).
func set_state(new_state: State, fade_duration: float = 1.0, variant_index: int = -1, allow_random: bool = true) -> bool:
	if new_state == State.NONE:
		stop_music(fade_duration)
		return true
	if not has_tracks_for(new_state):
		return false
	var pool: Array = _tracks[int(new_state)]
	var picked: MusicTrack = null
	if variant_index >= 0:
		picked = pool[clampi(variant_index, 0, pool.size() - 1)] as MusicTrack
	elif allow_random and pool.size() > 1:
		picked = pool[randi() % pool.size()] as MusicTrack
	else:
		picked = pool[0] as MusicTrack
	if not play_track(picked, fade_duration):
		return false
	_set_current_state(new_state)
	return true

## Stops playback. fade_duration > 0 ramps the active voice down first.
## Explicit stops always reset the logical state to NONE.
func stop_music(fade_duration: float = 0.0) -> bool:
	_generation += 1
	var gen: int = _generation
	_loop_current = false
	_paused = false
	_current_track = null
	if fade_duration > 0.0 and is_inside_tree() and _active_voice.playing:
		_kill_transition()
		_tween = create_tween()
		_tween.tween_property(_active_voice, "volume_db", FADE_FLOOR_DB, fade_duration)
		_tween.tween_callback(_finish_stop.bind(gen))
	else:
		_kill_transition()
		_hard_stop_voice(_active_voice)
		_hard_stop_voice(_fadeout_voice)
	_set_current_state(State.NONE)
	return true

## Convenience wrapper: fade the current music out and end in NONE.
func fade_out(fade_duration: float = 1.0) -> bool:
	return stop_music(fade_duration)

func pause_music() -> bool:
	if _active_voice == null or not _is_audible():
		return false
	_active_voice.stream_paused = true
	if _fadeout_voice.playing:
		_fadeout_voice.stream_paused = true
	_paused = true
	return true

func resume_music() -> bool:
	if _active_voice == null or not _paused:
		return false
	_active_voice.stream_paused = false
	if _fadeout_voice.playing:
		_fadeout_voice.stream_paused = false
	_paused = false
	return true

## ──────────────────────────────────────────────
## QUERIES
## ──────────────────────────────────────────────

func get_current_state() -> State:
	return _current_state

## Last track started. Remains queryable after a natural (non-looped) finish
## so callers can inspect what just played; cleared only by explicit stops.
func get_current_track() -> MusicTrack:
	return _current_track

func is_playing() -> bool:
	return _is_audible() and not _paused

func is_paused() -> bool:
	return _paused

## ──────────────────────────────────────────────
## MUSIC-BUS VOLUME (never touches Master)
## ──────────────────────────────────────────────

## Sets the Music bus volume from a 0..1 linear value. Delegates to the
## AudioManager bus helpers so there is exactly one bus-volume code path;
## Master remains owned by GameConfig.
func set_music_volume(linear: float) -> bool:
	if _audio_manager == null:
		return false
	return _audio_manager.set_bus_volume_linear(BUS_MUSIC, clampf(linear, 0.0, 1.0))

func get_music_volume() -> float:
	if _audio_manager == null:
		return 0.0
	return _audio_manager.get_bus_volume_linear(BUS_MUSIC)

## ──────────────────────────────────────────────
## INTERNALS
## ──────────────────────────────────────────────

func _create_voice() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = BUS_MUSIC
	player.volume_db = FADE_FLOOR_DB
	add_child(player)
	player.finished.connect(_on_voice_finished.bind(player))
	return player

func _begin_voice(player: AudioStreamPlayer, track: MusicTrack, gen: int) -> void:
	player.set_meta("gen", gen)
	player.stream = track.stream
	player.pitch_scale = 1.0
	player.stream_paused = false
	player.play()

func _hard_stop_voice(player: AudioStreamPlayer) -> void:
	player.stop()
	player.stream = null
	player.volume_db = FADE_FLOOR_DB

func _kill_transition() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _fadeout_voice != null and (_fadeout_voice.playing or _fadeout_voice.stream != null):
		_hard_stop_voice(_fadeout_voice)

func _finish_fadeout(gen: int) -> void:
	# A newer transition may have swapped roles; only release if still ours.
	if gen != _generation:
		return
	_hard_stop_voice(_fadeout_voice)

func _finish_stop(gen: int) -> void:
	if gen != _generation:
		return
	_hard_stop_voice(_active_voice)

func _on_voice_finished(player: AudioStreamPlayer) -> void:
	if player != _active_voice:
		return  # Crossfade victims stopping/restarting are irrelevant here.
	if int(player.get_meta("gen", -1)) != _generation:
		return
	if _loop_current and not _paused and player.stream != null:
		player.play()  # Config-driven loop: restart from the top.

func _is_audible() -> bool:
	return _active_voice != null and _active_voice.stream != null \
		and _active_voice.playing and not _active_voice.stream_paused

func _set_current_state(new_state: State) -> void:
	if _current_state == new_state:
		return
	_current_state = new_state
	state_changed.emit(new_state)
