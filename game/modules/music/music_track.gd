# music_track.gd
# Technical Rationale: Minimal data descriptor for one music track. Keeps the
# MusicController free of hardcoded filenames: states hold arrays of these
# descriptors, so a state may have a single track or several variants, and
# looping/volume are explicit per track instead of inferred from file format.
# A plain Resource (no custom editor plugin, no registry) is enough for V1 and
# can later be serialized into scene/tooling configuration unchanged.
class_name MusicTrack
extends Resource

## Stable identifier used by callers/tests to query which track is active.
@export var id: StringName = &""
## Audio stream to play on the Music bus.
@export var stream: AudioStream = null
## Explicit loop switch. Result/transition tracks default to false; intro and
## combat tracks are expected to register true, but nothing is hardcoded.
@export var loop: bool = false
## Per-track gain offset applied on top of the Music bus volume.
@export var volume_db: float = 0.0
