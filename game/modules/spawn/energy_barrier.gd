# energy_barrier.gd
# Technical Rationale: Permanent energy field that guards a team's spawn room.
# Always visible and active (no door animation): the owning team passes through
# freely in both directions while the enemy team is physically blocked. Uses
# dedicated collision-layer bits so passage is decided by each operator's
# CharacterBody3D collision_mask (set per team in OperatorBase._ready), not by
# any per-frame logic or Area3D timing. Robust in headless tests.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name EnergyBarrier
extends StaticBody3D

## World group so Match/tests can discover every energy barrier.
const GROUP: String = "energy_barriers"

## Team whose spawn room this barrier guards.
@export var team_id: int = OperatorBase.TEAM_ATTACKERS

## Panel footprint: X = length along the room edge, Y = height (3.0 m walls).
@export var barrier_size: Vector2 = Vector2(5.0, 3.0)

const TEAM_COLOR_ATTACKERS: Color = Color(0.2, 0.55, 1.0)
const TEAM_COLOR_DEFENDERS: Color = Color(1.0, 0.25, 0.2)

func _ready() -> void:
	add_to_group(GROUP)
	## A StaticBody3D only blocks bodies whose collision_mask includes its layer.
	## Own team's mask excludes this layer (passes), enemy team's mask includes
	## it (blocked). No masks are touched here beyond the dedicated bit.
	collision_layer = barrier_collision_layer(team_id)
	collision_mask = 0
	_build_visual()

## Collision layer bit used by a team's own spawn barrier:
## - Team 0 (attackers) barrier -> bit 3 (value 4), which only defenders mask in.
## - Team 1 (defenders) barrier -> bit 4 (value 8), which only attackers mask in.
## See OperatorBase._team_collision_mask() for the matching mask logic.
static func barrier_collision_layer(team: int) -> int:
	return 4 if team == OperatorBase.TEAM_ATTACKERS else 8

func _build_visual() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(barrier_size.x, barrier_size.y, 0.12)
	shape.shape = box
	add_child(shape)

	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.name = "BarrierMesh"
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(barrier_size.x, barrier_size.y, 0.1)
	var team_color: Color = TEAM_COLOR_ATTACKERS if team_id == OperatorBase.TEAM_ATTACKERS else TEAM_COLOR_DEFENDERS
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(team_color.r, team_color.g, team_color.b, 0.45)
	mat.emission_enabled = true
	mat.emission = team_color * 0.9
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.2
	mat.metallic = 0.4
	pm.material = mat
	panel.mesh = pm
	add_child(panel)
