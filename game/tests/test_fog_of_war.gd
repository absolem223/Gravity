# test_fog_of_war.gd
# Technical Rationale: Deterministic headless tests for the FogOfWar data layer:
# grid setup, initial unexplored state, vision circle exploration, the persistent
# explored-but-not-visible state, per-player independence, the UNION display
# policy, clear_player and reset. Pure data tests: no scene tree, no match.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
#
# Run: godot --headless --path game --script res://tests/test_fog_of_war.gd

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

func run_test() -> void:
	print("== FOG OF WAR DATA LAYER TEST ==")
	var fog: FogOfWar = FogOfWar.new()
	fog.setup(Vector2(72.0, 56.0), 0.5)

	_check(fog.grid_cols == 144 and fog.grid_rows == 112,
		"grid is 144x112 for 72x56 @ 0.5m cells (got %dx%d)" % [fog.grid_cols, fog.grid_rows])

	# 1. Initial unexplored map.
	_check(fog.state_at_world(1, Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"initial map is NEVER_EXPLORED at origin (P1)")
	_check(fog.state_union_at_world([1, 2], Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"initial UNION display is NEVER_EXPLORED")

	# 2. Exploring new territory: P1 at origin, radius 2m.
	fog.update_vision(1, Vector3(0.0, 0.0, 0.0), 2.0)
	_check(fog.state_at_world(1, Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.VISIBLE,
		"P1 origin cell becomes VISIBLE after update_vision")
	_check(fog.state_at_world(1, Vector3(1.0, 0.0, 1.0)) == FogOfWar.FogState.VISIBLE,
		"P1 cell inside radius (1,1) is VISIBLE")
	_check(fog.state_at_world(1, Vector3(10.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"P1 cell far outside radius stays NEVER_EXPLORED")
	_check(fog.is_explored(1, 72, 56) and fog.is_visible(1, 72, 56),
		"explored + visible bitmask both set on origin cell (col 72,row 56)")

	# 3. Previously explored territory remains visible in obscured form.
	fog.update_vision(1, Vector3(10.0, 0.0, 0.0), 2.0)
	_check(fog.state_at_world(1, Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.EXPLORED_NOT_VISIBLE,
		"P1 origin becomes EXPLORED_NOT_VISIBLE after moving away")
	_check(fog.state_at_world(1, Vector3(10.0, 0.0, 0.0)) == FogOfWar.FogState.VISIBLE,
		"P1 new position (10,0) is VISIBLE")
	_check(fog.is_explored(1, 72, 56) and not fog.is_visible(1, 72, 56),
		"origin explored bit persists, visible bit cleared")

	# 4. Per-player independence: P2 explores a different area.
	fog.update_vision(2, Vector3(10.0, 0.0, 0.0), 2.0)
	_check(fog.state_at_world(2, Vector3(10.0, 0.0, 0.0)) == FogOfWar.FogState.VISIBLE,
		"P2 sees its own area (10,0)")
	_check(fog.state_at_world(2, Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"P2 has NOT explored P1's origin area (independence)")
	_check(fog.state_at_world(1, Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.EXPLORED_NOT_VISIBLE,
		"P1 keeps its own explored state, unaffected by P2")

	# 5. UNION display policy.
	# P1 at (0,0) explored-only; P2 at (10,0) visible.
	_check(fog.state_union_at_world([1, 2], Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.EXPLORED_NOT_VISIBLE,
		"UNION: P1-explored origin shows as EXPLORED_NOT_VISIBLE (no one currently there)")
	_check(fog.state_union_at_world([1, 2], Vector3(10.0, 0.0, 0.0)) == FogOfWar.FogState.VISIBLE,
		"UNION: P2's visible area shows as VISIBLE")
	_check(fog.state_union_at_world([1, 2], Vector3(30.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"UNION: area nobody explored shows as NEVER_EXPLORED")

	# 6. clear_player and reset.
	fog.clear_player(1)
	_check(not fog.has_player_state(1), "clear_player drops P1 state")
	_check(fog.state_union_at_world([1, 2], Vector3(0.0, 0.0, 0.0)) == FogOfWar.FogState.NEVER_EXPLORED,
		"after clearing P1, origin is NEVER_EXPLORED in UNION (only P2 matters)")
	fog.reset()
	_check(not fog.has_player_state(2), "reset drops all players' state")

	# 7. Raw bitmask sizes match the grid.
	fog.update_vision(1, Vector3(0.0, 0.0, 0.0), 2.0)
	_check(fog.get_explored_mask(1).size() == fog.grid_cols * fog.grid_rows,
		"explored mask size equals grid cell count")
	_check(fog.get_visible_mask(1).size() == fog.grid_cols * fog.grid_rows,
		"visible mask size equals grid cell count")

	# 8. Player index guards.
	fog.update_vision(99, Vector3(0.0, 0.0, 0.0), 2.0)
	_check(not fog.has_player_state(99), "invalid player_id is ignored")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)