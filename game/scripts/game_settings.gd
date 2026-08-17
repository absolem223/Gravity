# game_settings.gd
# Technical Rationale: Runtime authority for GAME settings (gameplay/visual options
# that are NOT controller/input related). Kept as a separate autoload from
# GameConfig so game settings and controller settings evolve independently without
# touching the (protected) GameConfig surface. Persists to its own user:// file
# using the same ConfigFile pattern as GameConfig. Adheres to ADR-0001.
# NOTE: No class_name on purpose: under `--script`/`--check-only` the compile-time
# global is not resolvable, so consumers look it up via get_tree().get_root()
# .get_node_or_null("GameSettings") exactly like GameConfig.

extends Node

## Fog of War master switch. When false the whole Fog of War pipeline is skipped.
var fog_of_war_enabled: bool = true

## Brightness of the "explored but not currently visible" terrain layer.
## 0.0 = fully black, 1.0 = as bright as explored-active terrain.
var fog_explored_brightness: float = 0.35

## Brightness of the "currently visible / actively revealed" terrain layer.
## Deliberately a lighter grey than explored_brightness (0.35), not pure white:
## live reveal circles read as a subtle light-grey-on-grey contrast instead of a
## stark spotlight disc.
var fog_visible_brightness: float = 0.62

## Softness of the transition between visibility states (0.0 = hard edge).
var fog_edge_softness: float = 0.5

## Separate settings file: GameConfig.save_settings() rebuilds its own file
## wholesale, so sharing a file would clobber sections. Keeps the ConfigFile pattern.
const SETTINGS_PATH: String = "user://gravity_game_settings.cfg"

const SECTION_GAME: String = "game"

func _ready() -> void:
	load_settings()

## ── Persistence ────────────────────────────────────────────────────────────
## Persists every game setting. Called automatically on any change by the UI.
func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION_GAME, "fog_of_war_enabled", fog_of_war_enabled)
	cfg.set_value(SECTION_GAME, "fog_explored_brightness", fog_explored_brightness)
	cfg.set_value(SECTION_GAME, "fog_visible_brightness", fog_visible_brightness)
	cfg.set_value(SECTION_GAME, "fog_edge_softness", fog_edge_softness)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	fog_of_war_enabled = cfg.get_value(SECTION_GAME, "fog_of_war_enabled", true) as bool
	fog_explored_brightness = cfg.get_value(SECTION_GAME, "fog_explored_brightness", 0.35) as float
	fog_visible_brightness = cfg.get_value(SECTION_GAME, "fog_visible_brightness", 0.62) as float
	fog_edge_softness = cfg.get_value(SECTION_GAME, "fog_edge_softness", 0.5) as float
