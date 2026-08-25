# audio_manager.gd
# Technical Rationale: Foundation audio service (autoload singleton). Centralizes
# playback routing over the project bus layout (Master > SFX / UI / Environment /
# Music, defined in res://default_bus_layout.tres). V1 scope is deliberately
# minimal: a small round-robin pool of non-positional SFX players, one dedicated
# UI player, one dedicated Music player, native AudioStreamPlayer3D spawning for
# future spatial one-shots, and linear bus volume/mute access for future tools.
#
# Master-volume ownership stays with GameConfig (settings screen path:
# GameConfig.master_volume_linear -> apply_runtime_settings()). This manager
# NEVER writes the Master bus, so it cannot become a third volume authority
# competing with the existing configuration system.
#
# Spatial listening: GRAVITY keeps a single runtime gameplay camera
# (CameraController's child Camera3D). With no explicit AudioListener3D in the
# tree, Godot uses the current Camera3D position/orientation as the listener,
# so 3D one-shots spawned through play_sfx_3d() are natively spatialized
# relative to the actual gameplay viewpoint without duplicating camera logic.
# An explicit AudioListener3D can be attached later if multi-camera needs arise.
#
# NOTE: No class_name on purpose: under `--script`/`--check-only` the
# compile-time class table does not include autoloads (project convention,
# see game_settings.gd).
extends Node

## Bus names from res://default_bus_layout.tres.
const BUS_MASTER: StringName = &"Master"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_ENVIRONMENT: StringName = &"Environment"
const BUS_MUSIC: StringName = &"Music"

## Fixed pool size for fire-and-forget non-positional SFX one-shots.
const SFX_POOL_SIZE: int = 8

## Round-robin pool of non-positional SFX players (bus = SFX).
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
## Single-channel UI player (restarts per sound; bus = UI).
var _ui_player: AudioStreamPlayer = null
## Single-channel music player (restarts per track; bus = Music).
var _music_player: AudioStreamPlayer = null
## Parent for transient spatial one-shot players so they survive their emitter.
var _sfx_3d_root: Node3D = null

func _ready() -> void:
	# Keep audio alive while the tree is paused (menus/pause screens).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = BUS_UI
	add_child(_ui_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_sfx_3d_root = Node3D.new()
	_sfx_3d_root.name = "SFX3DRoot"
	add_child(_sfx_3d_root)

## ──────────────────────────────────────────────
## NON-POSITIONAL PLAYBACK
## ──────────────────────────────────────────────

## Plays a non-positional SFX one-shot on the SFX bus via the shared pool.
## Safe to call every frame/event: voices are recycled automatically.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

## Plays (or restarts) a sound on the dedicated UI channel (bus = UI). A new
## call interrupts the previous UI sound by design: interface feedback is
## latest-wins.
func play_ui_sound(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _ui_player == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.pitch_scale = pitch_scale
	_ui_player.play()

func stop_ui_sound() -> void:
	if _ui_player != null:
		_ui_player.stop()

## Stops every pooled SFX voice and the UI channel. Music is unaffected.
func stop_all_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_pool:
		player.stop()
	stop_ui_sound()

## ──────────────────────────────────────────────
## MUSIC
## ──────────────────────────────────────────────

## Plays (or switches) music on the Music bus. Looping is governed by the
## stream resource itself (e.g. AudioStreamMP3.loop), not by this manager.
func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _music_player == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		_music_player.volume_db = volume_db
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

## ──────────────────────────────────────────────
## SPATIAL (3D) FOUNDATION
## ──────────────────────────────────────────────
## Native Godot spatialization only — no manual distance attenuation math.

## Spawns a transient AudioStreamPlayer3D one-shot at a world position on the
## SFX bus. The node frees itself when playback finishes. Returns the player
## so callers may tune spatial properties (unit_size, attenuation model) before
## or while it plays.
func play_sfx_3d(stream: AudioStream, at: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0, max_distance_m: float = 40.0) -> AudioStreamPlayer3D:
	if stream == null or _sfx_3d_root == null:
		return null
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.bus = BUS_SFX
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = max_distance_m
	player.position = at
	_sfx_3d_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

## ──────────────────────────────────────────────
## BUS ACCESS
## ──────────────────────────────────────────────

## True when the bus exists in the loaded layout.
func has_bus(bus: StringName) -> bool:
	return AudioServer.get_bus_index(bus) >= 0

## Sets a bus volume from a 0..1 linear value (never touches Master here;
## Master remains owned by GameConfig/settings).
func set_bus_volume_linear(bus: StringName, linear: float) -> bool:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return false
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	return true

## Reads a bus volume as a 0..1 linear value (-inf dB clamps to 0.0).
func get_bus_volume_linear(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func set_bus_muted(bus: StringName, muted: bool) -> bool:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return false
	AudioServer.set_bus_mute(idx, muted)
	return true

func is_bus_muted(bus: StringName) -> bool:
	var idx: int = AudioServer.get_bus_index(bus)
	return idx >= 0 and AudioServer.is_bus_mute(idx)

## ──────────────────────────────────────────────
## INTERNALS
## ──────────────────────────────────────────────

func _next_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			return player
	# All voices busy: steal round-robin (oldest scheduled first).
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	return _sfx_pool[_sfx_pool_index]
