# fog_of_war.gd
# Technical Rationale: Pure data layer for the Fog of War system (Age of Empires
# style). Maintains INDEPENDENT exploration/visibility state per player over a
# flat world grid. RefCounted on purpose: no scene tree dependency, fully
# deterministic and testable headless. Phase 1 only carries the data model and the
# per-player update/query API; rendering (Phase 2), entity gating (Phase 3) and UI
# (Phase 4) are out of scope here.
#
# Grid model:
#   - world coordinates are the arena floor plane (y=0); only X/Z matter.
#   - each cell stores two booleans per player: `explored` (persistent once seen)
#     and `visible` (transient, recomputed every update from vision circles).
#   - the three AoE states derive from those bits:
#       NEVER_EXPLORED              = not explored
#       VISIBLE                     = visible (implies explored)
#       EXPLORED_NOT_VISIBLE        = explored but not currently visible
#   - display policy is UNION (decision #1): on the shared screen a cell is shown
#     as visible if ANY human player currently sees it, and as explored if ANY
#     player has ever explored it.
#
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name FogOfWar
extends RefCounted

## Public display state of a cell.
enum FogState {
	NEVER_EXPLORED = 0,
	EXPLORED_NOT_VISIBLE = 1,
	VISIBLE = 2,
}

## Default grid resolution (meters per cell). Arena is 72x56 -> 144x112 cells.
const DEFAULT_CELL_SIZE: float = 0.5

## Max supported players (mirrors InputProfiles.MAX_PLAYERS).
const MAX_PLAYERS: int = 4

## World-space bounds of the fog grid. X = width (m), Y = depth (m).
var world_size: Vector2 = Vector2(72.0, 56.0)

## Cell edge length in meters.
var cell_size: float = DEFAULT_CELL_SIZE

## Number of grid columns / rows (derived from world_size / cell_size).
var grid_cols: int = 0
var grid_rows: int = 0

## Half-extents of the grid in world units.
var _half_x: float = 0.0
var _half_z: float = 0.0

## Per-player explored bitmask, player_id -> PackedByteArray (1 = explored).
var _explored: Dictionary = {}

## Per-player currently-visible bitmask, player_id -> PackedByteArray (1 = visible).
var _visible: Dictionary = {}

## ── Setup / reset ──────────────────────────────────────────────────────────
func setup(world: Vector2 = Vector2(72.0, 56.0), cell: float = DEFAULT_CELL_SIZE) -> void:
	world_size = world
	cell_size = maxf(cell, 0.1)
	grid_cols = maxi(int(roundf(world_size.x / cell_size)), 1)
	grid_rows = maxi(int(roundf(world_size.y / cell_size)), 1)
	_half_x = world_size.x * 0.5
	_half_z = world_size.y * 0.5
	reset()

## Clears all per-player state (fresh match).
func reset() -> void:
	_explored.clear()
	_visible.clear()

## ── Per-player updates ─────────────────────────────────────────────────────
## Marks every cell within `radius` meters of `world_pos` (X/Z only) as visible
## AND explored for `player_id`. Cells outside the circle lose their "visible"
## flag but KEEP their "explored" flag (the explored-but-not-visible state).
func update_vision(player_id: int, world_pos: Vector3, radius: float) -> void:
	if not _player_index_valid(player_id):
		return
	# PackedByteArray is a VALUE type in Godot 4: mutating a reference retrieved
	# from a Dictionary does not persist. Pull into locals, mutate, write back.
	var exp: PackedByteArray = _explored.get(player_id, PackedByteArray()) as PackedByteArray
	var vis: PackedByteArray = _visible.get(player_id, PackedByteArray()) as PackedByteArray
	if exp.size() != grid_cols * grid_rows:
		exp.resize(grid_cols * grid_rows)
	if vis.size() != grid_cols * grid_rows:
		vis.resize(grid_cols * grid_rows)
	vis.fill(0)

	var r_cells: int = maxi(int(ceilf(radius / cell_size)), 0)
	var center: Vector2i = _world_to_cell(world_pos)
	var r2: float = radius * radius
	for row: int in range(maxi(center.y - r_cells, 0), mini(center.y + r_cells + 1, grid_rows)):
		var cz: float = _cell_center_z(row)
		for col: int in range(maxi(center.x - r_cells, 0), mini(center.x + r_cells + 1, grid_cols)):
			var cx: float = _cell_center_x(col)
			var dx: float = cx - world_pos.x
			var dz: float = cz - world_pos.z
			if dx * dx + dz * dz <= r2:
				var idx: int = row * grid_cols + col
				vis[idx] = 1
				exp[idx] = 1

	_explored[player_id] = exp
	_visible[player_id] = vis

## Drops all state for one player (used when a slot is disabled).
func clear_player(player_id: int) -> void:
	if _explored.has(player_id):
		_explored.erase(player_id)
	if _visible.has(player_id):
		_visible.erase(player_id)

## ── Per-player queries ─────────────────────────────────────────────────────
func is_explored(player_id: int, col: int, row: int) -> bool:
	var exp: PackedByteArray = _explored.get(player_id, PackedByteArray()) as PackedByteArray
	if exp.is_empty() or not _cell_in_bounds(col, row):
		return false
	return exp[row * grid_cols + col] == 1

func is_visible(player_id: int, col: int, row: int) -> bool:
	var vis: PackedByteArray = _visible.get(player_id, PackedByteArray()) as PackedByteArray
	if vis.is_empty() or not _cell_in_bounds(col, row):
		return false
	return vis[row * grid_cols + col] == 1

## FogState for a single player at a cell.
func state_at(player_id: int, col: int, row: int) -> FogState:
	if is_visible(player_id, col, row):
		return FogState.VISIBLE
	if is_explored(player_id, col, row):
		return FogState.EXPLORED_NOT_VISIBLE
	return FogState.NEVER_EXPLORED

## FogState for a single player at a world position.
func state_at_world(player_id: int, world_pos: Vector3) -> FogState:
	var c: Vector2i = _world_to_cell(world_pos)
	return state_at(player_id, c.x, c.y)

## ── Display (UNION policy, decision #1) ────────────────────────────────────
## FogState as shown on the shared screen: VISIBLE if any listed player sees it,
## EXPLORED_NOT_VISIBLE if any listed player ever explored it, else NEVER_EXPLORED.
func state_union(player_ids: Array[int], col: int, row: int) -> FogState:
	for p: int in player_ids:
		if is_visible(p, col, row):
			return FogState.VISIBLE
	for p: int in player_ids:
		if is_explored(p, col, row):
			return FogState.EXPLORED_NOT_VISIBLE
	return FogState.NEVER_EXPLORED

func state_union_at_world(player_ids: Array[int], world_pos: Vector3) -> FogState:
	var c: Vector2i = _world_to_cell(world_pos)
	return state_union(player_ids, c.x, c.y)

## Raw bitmask accessors (used by the renderer in Phase 2 / tests).
func get_explored_mask(player_id: int) -> PackedByteArray:
	return _explored.get(player_id, PackedByteArray()) as PackedByteArray

func get_visible_mask(player_id: int) -> PackedByteArray:
	return _visible.get(player_id, PackedByteArray()) as PackedByteArray

## Whether a player has any state at all (slot never spawned / cleared).
func has_player_state(player_id: int) -> bool:
	return _explored.has(player_id)

## ── Internals ──────────────────────────────────────────────────────────────
func _player_index_valid(player_id: int) -> bool:
	return player_id >= 1 and player_id <= MAX_PLAYERS

func _cell_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < grid_cols and row >= 0 and row < grid_rows

func _world_to_cell(world_pos: Vector3) -> Vector2i:
	var col: int = int(floorf((world_pos.x + _half_x) / cell_size))
	var row: int = int(floorf((world_pos.z + _half_z) / cell_size))
	col = clampi(col, 0, grid_cols - 1)
	row = clampi(row, 0, grid_rows - 1)
	return Vector2i(col, row)

func _cell_center_x(col: int) -> float:
	return (col + 0.5) * cell_size - _half_x

func _cell_center_z(row: int) -> float:
	return (row + 0.5) * cell_size - _half_z
