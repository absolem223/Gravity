# music_library.gd
# Technical Rationale: Wiring layer between the real music assets on disk and
# the existing MusicController. Responsibility is strictly discover -> load ->
# register: it scans ONLY res://audio/music/ and the six canonical state
# directories (intro/combat/transition/victory/defeat/draw), turns every
# valid native audio file into a MusicTrack variant of its directory's state,
# and hands them to the controller. Playback stays in MusicController; this
# class never plays anything and must be initialized explicitly by the music
# system owner (no autoload, no boot-time hook).
#
# Loop policy is per canonical category, not per filename guesswork:
# INTRO/COMBAT loop (sustained beds), TRANSITION/VICTORY/DEFEAT/DRAW are
# one-shot result/connector cues. Per-track overrides remain possible by
# mutating the returned MusicTrack resources or registering manually.
#
# Filesystem safety: a missing category directory or an unloadable file is
# recorded in `errors` and skipped — registration never crashes and never
# half-corrupts the track list.
class_name MusicLibrary
extends RefCounted

const MUSIC_ROOT := "res://audio/music"

## Canonical runtime categories (directory name -> controller state).
const STATE_DIRS: Dictionary = {
	MusicController.State.INTRO: "intro",
	MusicController.State.COMBAT: "combat",
	MusicController.State.TRANSITION: "transition",
	MusicController.State.VICTORY: "victory",
	MusicController.State.DEFEAT: "defeat",
	MusicController.State.DRAW: "draw",
}

## Category loop defaults. Result/connector states stay one-shot.
const LOOP_BY_STATE: Dictionary = {
	int(MusicController.State.INTRO): true,
	int(MusicController.State.COMBAT): true,
	int(MusicController.State.TRANSITION): false,
	int(MusicController.State.VICTORY): false,
	int(MusicController.State.DEFEAT): false,
	int(MusicController.State.DRAW): false,
}

## Native formats importable by this project's pipeline.
const SUPPORTED_EXTENSIONS: PackedStringArray = ["mp3", "ogg", "wav"]

## Diagnostics from the last populate() run (empty when fully clean).
var errors: PackedStringArray = []
## Tracks created by the last populate() run, keyed by controller state.
var tracks_by_state: Dictionary = {}

static func is_supported_audio_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return SUPPORTED_EXTENSIONS.has(ext)

## Discovers, loads and registers every supported audio file found under the
## canonical directories. Returns the total number of registered tracks.
func populate(controller: MusicController) -> int:
	errors = []
	tracks_by_state = {}
	var total: int = 0
	for state_value: int in STATE_DIRS:
		var dir_name: String = STATE_DIRS[state_value]
		var tracks := _scan_state_dir(dir_name, state_value)
		tracks_by_state[state_value] = tracks
		for track: MusicTrack in tracks:
			controller.register_track(state_value as MusicController.State, track)
			total += 1
	return total

func get_registered_count_for(state: int) -> int:
	if not tracks_by_state.has(state):
		return 0
	return (tracks_by_state[state] as Array).size()

## ──────────────────────────────────────────────
## INTERNALS
## ──────────────────────────────────────────────

func _scan_state_dir(dir_name: String, state_value: int) -> Array:
	var tracks: Array = []
	var dir_path := MUSIC_ROOT.path_join(dir_name)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# Missing category is a normal, non-fatal condition (e.g. no victory
		# assets yet): record and continue so remaining categories still load.
		errors.append("missing directory: %s" % dir_path)
		return tracks
	var file_names: PackedStringArray = _list_audio_files(dir)
	file_names.sort()
	for file_name in file_names:
		var track := _load_track(dir_path.path_join(file_name), file_name, state_value)
		if track != null:
			tracks.append(track)
	return tracks

func _list_audio_files(dir: DirAccess) -> PackedStringArray:
	var names := PackedStringArray()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and is_supported_audio_file(entry):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return names

func _load_track(res_path: String, file_name: String, state_value: int) -> MusicTrack:
	var stream: AudioStream = null
	if ResourceLoader.exists(res_path):
		stream = load(res_path)
	if stream == null or not (stream is AudioStream):
		errors.append("unloadable audio resource skipped: %s" % res_path)
		return null
	var track := MusicTrack.new()
	track.id = StringName(file_name.get_basename())
	track.stream = stream
	track.loop = LOOP_BY_STATE[int(state_value)]
	track.volume_db = 0.0
	return track
