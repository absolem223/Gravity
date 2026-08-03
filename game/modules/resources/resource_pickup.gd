# resource_pickup.gd
# Technical Rationale: Physical pickup node. Represents a collectible resource in the map.
# Auto-collects when an OperatorBase enters the Area3D. Emits signal and destroys itself.
# Map-independent: only requires operators to be in group "players".
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ResourcePickup
extends Area3D

## ──────────────────────────────────────────────
## SIGNALS
## ──────────────────────────────────────────────
signal collected(resource_type: String, amount: int, collector_id: int)

## ──────────────────────────────────────────────
## CONFIGURATION
## ──────────────────────────────────────────────
@export var resource_type: String = ResourceInventory.TYPE_MAINTENANCE
@export_range(1, 50, 1) var amount: int = 10

## Pulse animation speed (visual feedback)
@export var pulse_speed: float = 3.0

## ──────────────────────────────────────────────
## INTERNAL NODES
## ──────────────────────────────────────────────
var _mesh: MeshInstance3D = null
var _collision: CollisionShape3D = null
var _label: Label3D = null

## Lifetime accumulator for pulse animation
var _time: float = 0.0

## Whether this pickup has been consumed (prevents double-collect)
var _consumed: bool = false

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("resource_pickups")
	_build_visuals()
	print("[ResourcePickup] Spawned: %d x %s at %s" % [amount, resource_type, str(global_position)])

func _process(delta: float) -> void:
	if _consumed:
		return
	_time += delta
	_animate_pulse()

## ──────────────────────────────────────────────
## VISUAL CONSTRUCTION
## ──────────────────────────────────────────────
func _build_visuals() -> void:
	## Collision shape (sphere)
	_collision = CollisionShape3D.new()
	_collision.name = "CollisionShape3D"
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	_collision.shape = sphere
	add_child(_collision)

	## Pickup mesh (small glowing octahedron approximated with sphere mesh)
	_mesh = MeshInstance3D.new()
	_mesh.name = "MeshInstance3D"
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	sphere_mesh.height = 0.6
	_mesh.mesh = sphere_mesh
	_mesh.position = Vector3(0.0, 0.3, 0.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.35)
	mat.emission_energy_multiplier = 1.5
	_mesh.material_override = mat
	add_child(_mesh)

	## Floating label above pickup
	_label = Label3D.new()
	_label.name = "PickupLabel"
	_label.text = "+%d COMP" % amount
	_label.font_size = 22
	_label.position = Vector3(0.0, 0.9, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(0.3, 1.0, 0.65)
	add_child(_label)

## ──────────────────────────────────────────────
## ANIMATION
## ──────────────────────────────────────────────
func _animate_pulse() -> void:
	if _mesh == null:
		return
	## Vertical bobbing
	_mesh.position.y = 0.3 + sin(_time * pulse_speed) * 0.08
	## Rotation
	_mesh.rotation.y += 0.02

## ──────────────────────────────────────────────
## COLLECTION LOGIC
## ──────────────────────────────────────────────
func _on_body_entered(body: Node3D) -> void:
	if _consumed:
		return

	if body is OperatorBase:
		var op: OperatorBase = body as OperatorBase
		if op.is_incapacitated:
			return

		## Attempt to add resource to operator's inventory
		var added: int = 0
		if op.inventory != null:
			added = op.inventory.add_resource(resource_type, amount)
		else:
			## Fallback: collect_resource wrapper
			added = op.collect_resource(resource_type, amount)

		if added > 0:
			_consumed = true
			collected.emit(resource_type, added, op.player_id)
			print("[ResourcePickup] Collected by P%d: %d x %s" % [op.player_id, added, resource_type])
			queue_free()

## ──────────────────────────────────────────────
## FACTORY CONSTRUCTOR
## ──────────────────────────────────────────────

## Spawns a ResourcePickup at the given world position.
## Caller is responsible for add_child().
static func create(res_type: String, res_amount: int, world_pos: Vector3) -> ResourcePickup:
	var pickup: ResourcePickup = ResourcePickup.new()
	pickup.resource_type = res_type
	pickup.amount = res_amount
	pickup.global_position = world_pos
	return pickup
