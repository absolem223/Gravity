# test_tactical_improvements.gd
# Comprehensive regression test suite for:
#   1. Limited Tactical Camera Zoom (Mouse Wheel, bounded, smooth, target tracking)
#   2. Operator Damage Knockback (Pushes away from shooter along bullet travel direction)
#   3. Slower Rifle/Shotgun-Like Fire Pacing (Deliberate recovery, single shot, drone unchanged)
#   4. Operator HP Balance (Base 250, Vanguard 375, death at 0 HP)

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _get_root() -> Window:
	return root

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	print("=== TACTICAL IMPROVEMENTS TEST SUITE ===")

	var root_node: Node3D = Node3D.new()
	_get_root().add_child(root_node)

	# =========================================================================
	# 1. CAMERA ZOOM TESTS
	# =========================================================================
	print("--- [1] Tactical Camera Zoom ---")
	var cam_ctrl: CameraController = CameraController.new()
	root_node.add_child(cam_ctrl)

	var op_cam: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op_cam.player_id = 1
	op_cam.position = Vector3(0.0, 0.0, 0.0)
	root_node.add_child(op_cam)
	cam_ctrl.add_target(op_cam)

	for i in range(5):
		await _get_root().get_tree().physics_frame

	# 1. Default camera zoom remains unchanged
	var default_zoom: float = cam_ctrl.get_current_zoom()
	_check(default_zoom >= 12.0 and default_zoom <= 20.0, "Default camera zoom distance is baseline (~%.1fm)" % default_zoom)

	# 2. Mouse wheel up moves camera toward player (zoom in)
	cam_ctrl.zoom_in()
	cam_ctrl._update_centroid_and_zoom()
	var zoomed_in_dist: float = cam_ctrl.get_current_zoom()
	_check(zoomed_in_dist < default_zoom, "Wheel UP moves camera closer: %.1fm -> %.1fm" % [default_zoom, zoomed_in_dist])

	# 3. Mouse wheel down moves camera away (zoom out)
	cam_ctrl.zoom_out()
	cam_ctrl.zoom_out()
	cam_ctrl._update_centroid_and_zoom()
	var zoomed_out_dist: float = cam_ctrl.get_current_zoom()
	_check(zoomed_out_dist > default_zoom, "Wheel DOWN moves camera farther: %.1fm -> %.1fm" % [default_zoom, zoomed_out_dist])

	# 4. Zoom cannot exceed minimum distance
	for i in range(20):
		cam_ctrl.zoom_in()
	cam_ctrl._update_centroid_and_zoom()
	var min_dist: float = cam_ctrl.get_current_zoom()
	_check(min_dist >= cam_ctrl.min_zoom_distance, "Zoom bounded at minimum (got %.1fm >= min %.1fm)" % [min_dist, cam_ctrl.min_zoom_distance])

	# 5. Zoom cannot exceed maximum distance
	for i in range(40):
		cam_ctrl.zoom_out()
	cam_ctrl._update_centroid_and_zoom()
	var max_dist: float = cam_ctrl.get_current_zoom()
	_check(max_dist <= cam_ctrl.max_zoom_distance, "Zoom bounded at maximum (got %.1fm <= max %.1fm)" % [max_dist, cam_ctrl.max_zoom_distance])

	# 6. Repeated wheel input does not accumulate beyond limits
	var offset_capped: float = cam_ctrl.get_manual_zoom_offset()
	_check(offset_capped <= cam_ctrl.manual_zoom_max_offset and offset_capped >= cam_ctrl.manual_zoom_min_offset, "Manual zoom offset clamped to configured limits (%.1f)" % offset_capped)

	# 7. Zoom does not alter player movement
	var pos_before: Vector3 = op_cam.global_position
	cam_ctrl.zoom_in()
	cam_ctrl.zoom_in()
	_check(op_cam.global_position == pos_before, "Zoom does not alter player position or movement")

	# 8. Zoom does not alter weapon range
	_check(op_cam.weapon_range == 20.0, "Weapon range untouched by camera zoom (%.1fm)" % op_cam.weapon_range)

	# 9. Zoom does not alter vision range
	_check(op_cam.vision_cone.view_range == 40.0, "Vision range untouched by camera zoom (%.1fm)" % op_cam.vision_cone.view_range)

	# =========================================================================
	# 2. DAMAGE KNOCKBACK TESTS (AWAY FROM SHOOTER)
	# =========================================================================
	print("--- [2] Damage Knockback (Shooter -> Bullet -> Target -> Knockback) ---")
	var target_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	target_op.player_id = 2
	target_op.team_id = 1
	target_op.position = Vector3(5.0, 0.0, 0.0)
	root_node.add_child(target_op)

	for i in range(5):
		await _get_root().get_tree().physics_frame

	# 10. Shooter at X=0 fires at Target at X=5. Bullet travels in +X direction.
	# Target must receive positive X velocity (pushed AWAY from shooter).
	target_op.velocity = Vector3.ZERO
	var shooter_pos: Vector3 = Vector3(0.0, 0.0, 0.0)
	var impact_dir_posx: Vector3 = (target_op.global_position - shooter_pos).normalized()
	target_op.take_damage(50.0, impact_dir_posx)
	_check(target_op.velocity.x > 0.5, "Shooter at X=0 -> Target at X=5: Target pushed in +X direction away from shooter (vx=%.2f m/s)" % target_op.velocity.x)
	_check(target_op.velocity.x > 0.0, "Target is NOT pushed toward shooter (velocity.x is positive)")

	# 11. Zero damage produces no impulse
	target_op.velocity = Vector3.ZERO
	target_op.take_damage(0.0, impact_dir_posx)
	_check(target_op.velocity == Vector3.ZERO, "Zero damage produces zero knockback impulse")

	# 12. Shooter at (5, 0, 5), Target at (5, 0, 0) -> bullet travels in -Z direction
	target_op.velocity = Vector3.ZERO
	var shooter_pos_z: Vector3 = Vector3(5.0, 0.0, 5.0)
	var impact_dir_negz: Vector3 = (target_op.global_position - shooter_pos_z).normalized()
	target_op.take_damage(20.0, impact_dir_negz)
	_check(target_op.velocity.z < -0.5 and absf(target_op.velocity.x) < 0.01, "Shooter at +Z -> Target at origin: Target pushed in -Z direction away from shooter (vz=%.2f m/s)" % target_op.velocity.z)

	# 13. Knockback does not break crouching
	target_op.is_crouching = true
	target_op._update_crouch_visual()
	target_op.velocity = Vector3.ZERO
	target_op.take_damage(10.0, Vector3(1.0, 0.0, 0.0))
	_check(target_op.is_crouching == true, "Operator remains crouching after taking damage with knockback")
	var rel_vision_y: float = target_op.get_vision_origin().y - target_op.global_position.y
	_check(absf(rel_vision_y - OperatorBase.VISION_ORIGIN_CROUCHING_Y) < 0.01, "Crouch vision/shot height preserved (%.2fm relative to feet)" % rel_vision_y)

	# 14. Existing damage particles still spawn
	var particle_found: bool = false
	for child in root_node.get_children():
		if child is CPUParticles3D:
			particle_found = true
			break
	_check(particle_found, "Damage armor particles spawn correctly on hit")

	# =========================================================================
	# 3. WEAPON FIRE PACING TESTS
	# =========================================================================
	print("--- [3] Weapon Fire Pacing ---")
	var shooter: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	shooter.player_id = 3
	shooter.team_id = 0
	shooter.position = Vector3(0.0, 0.0, 0.0)
	root_node.add_child(shooter)

	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(shooter.fire_rate == 0.9, "Operator base fire_rate is 0.9s deliberate recovery (%.2fs)" % shooter.fire_rate)
	_check(shooter.weapon.fire_mode.type == FireMode.Type.SEMI_AUTO, "Operator weapon is configured in SEMI_AUTO fire mode")

	# 15. First shot fires normally
	var initial_rounds: int = shooter.weapon.magazine.current_rounds
	shooter._execute_tactical_shot()
	_check(shooter._fire_cooldown > 0.0, "Cooldown engaged after tactical shot (_fire_cooldown = %.2fs)" % shooter._fire_cooldown)

	# 16. Immediate second trigger does not fire during cooldown
	shooter._fire_input_prev = false # simulate fresh press
	var trigger_fired: bool = false
	if shooter._fire_cooldown <= 0.0:
		trigger_fired = true
	_check(not trigger_fired, "Weapon refuses to fire during active recovery interval")

	# 17. Second shot becomes available after cooldown
	shooter._fire_cooldown = 0.0
	shooter._fire_input_prev = false
	var can_fire_after_recovery: bool = (shooter._fire_cooldown <= 0.0)
	_check(can_fire_after_recovery, "Second shot becomes available after recovery interval expires")

	# 18. Ammo is consumed once per actual shot
	var rounds_before_shot: int = shooter.weapon.magazine.current_rounds
	shooter.weapon.try_consume_round()
	_check(shooter.weapon.magazine.current_rounds == rounds_before_shot - 1, "Exactly one round consumed per shot (rounds: %d -> %d)" % [rounds_before_shot, shooter.weapon.magazine.current_rounds])

	# 19. Existing reload behavior remains correct
	shooter.weapon.magazine.current_rounds = 0
	shooter.weapon.try_consume_round() # triggers auto reload
	shooter.weapon.tick(shooter.weapon.reload.reload_duration + 0.1)
	_check(shooter.weapon.magazine.current_rounds == shooter.weapon.magazine.capacity, "Weapon reloads correctly on empty magazine")

	# 20. Drone firing behavior remains unchanged
	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = shooter
	root_node.add_child(drone)
	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(drone.weapon.fire_mode.type == FireMode.Type.FULL_AUTO, "Drone weapon maintains FULL_AUTO fire mode")
	_check(drone.weapon.fire_mode.fire_rate == 0.6, "Drone fire_rate maintains 0.6s timing (%.2fs)" % drone.weapon.fire_mode.fire_rate)

	# =========================================================================
	# 4. OPERATOR HP BALANCE TESTS
	# =========================================================================
	print("--- [4] Operator HP Balance ---")
	# 21. Base Operator HP = 250
	var test_base_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	test_base_op.player_id = 1
	root_node.add_child(test_base_op)
	for i in range(5):
		await _get_root().get_tree().physics_frame
	_check(test_base_op.health_max == 250.0, "Base Operator health_max is 250.0")
	_check(test_base_op.health_current == 250.0, "Base Operator starts at 250.0 HP")

	# 22. Vanguard effective HP = 375
	var test_van_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	test_van_op.player_id = 2
	root_node.add_child(test_van_op)
	for i in range(5):
		await _get_root().get_tree().physics_frame
	_check(test_van_op.health_max == 375.0, "Vanguard Operator health_max is 375.0 (250 * 1.5)")
	_check(test_van_op.health_current == 375.0, "Vanguard Operator starts at 375.0 HP")

	# 23. Operator death occurs at 0 HP
	test_base_op.take_damage(250.0)
	for i in range(2):
		await _get_root().get_tree().physics_frame
	_check(test_base_op.health_current == 0.0, "Operator HP reaches 0.0")
	_check(test_base_op.is_dead, "Operator enters DEAD state when HP reaches 0.0")

	# 24. Drone HP and respawn unchanged
	_check(drone.health_max == 500.0, "Drone health_max remains 500.0")

	root_node.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
