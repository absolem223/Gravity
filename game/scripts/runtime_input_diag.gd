# runtime_input_diag.gd
# TEMPORARY live joystick/input diagnostic overlay. Always shown; purely
# presentational — the joystick aiming pipeline works identically whether this
# overlay is present or not.
# Shows, live, for every operator:
#   - connected joypads + their RAW axis values (LX/LY/RX/RY/triggers)
#   - the player profile (keyboard vs joystick slot, resolved device id)
#   - the InputManager-processed aim vector and movement vector
#   - the operator's aim state: is_gamepad_input(), diag_using_mouse(),
#     aim source, yaw/planar aim direction, and how many frames _update_aim_input_gamepad()
#     actually drove the aim (diag_aim_input_calls)
#   - the shared CameraController fixed rotation, to confirm right stick never drives it
class_name RuntimeInputDiag
extends CanvasLayer

var _label: Label = null

func _ready() -> void:
	layer = 100
	_label = Label.new()
	# Offset right so it never overlaps the sandbox's own debug label at (10,10).
	_label.position = Vector2(640, 10)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)

func _process(_delta: float) -> void:
	var cfg: Node = _game_config()
	var show_diag: bool = false
	if cfg != null and "show_joystick_diagnostics" in cfg:
		show_diag = cfg.show_joystick_diagnostics as bool
	if _label != null:
		_label.visible = show_diag
	if show_diag:
		_refresh()

## Runtime lookup of the GameConfig autoload (avoids the compile-time autoload
## identifier, which is not resolvable in --script / --check-only contexts).
func _game_config() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameConfig")

func _refresh() -> void:
	if _label == null:
		return
	var lines: Array[String] = []

	var pads: Array[int] = InputProfiles.get_connected_joypads()
	lines.append("PADS: %d %s" % [pads.size(), str(pads)])
	for dev: int in pads:
		lines.append("  dev%d \"%s\"  LX=%.2f LY=%.2f | RX=%.2f RY=%.2f | L2=%.2f R2=%.2f" % [
			dev,
			Input.get_joy_name(dev),
			Input.get_joy_axis(dev, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y),
			Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y),
			Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT),
			Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT),
		])

	var input_manager: InputManager = _find_input_manager()
	var cam: CameraController = _find_camera()

	var ops: Array[OperatorBase] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is OperatorBase:
			ops.append(node as OperatorBase)
	ops.sort_custom(func(a: OperatorBase, b: OperatorBase) -> bool: return a.player_id < b.player_id)

	for op: OperatorBase in ops:
		if not is_instance_valid(op):
			continue
		var prof: InputProfile = null
		var cfg: Node = _game_config()
		if cfg != null:
			prof = cfg.call("get_profile", op.player_id) as InputProfile
		var kind_s: String = "?"
		if prof != null:
			kind_s = "KB" if prof.is_keyboard() else "JOYslot%d(dev=%d)" % [prof.joystick_index, prof.get_joy_device_id()]
		var aimv: Vector2 = Vector2.ZERO
		var movev: Vector2 = Vector2.ZERO
		if input_manager != null:
			aimv = input_manager.get_aim_vector(op.player_id)
			movev = input_manager.get_movement_vector(op.player_id)
		var ai_s: String = " AI" if op.is_ai_controlled else ""
		lines.append("P%d%s prof=%s gp=%s mouse=%s src=%s aim=(%.2f,%.2f) mov=(%.2f,%.2f) yaw=%+.0f° dir=(%+.2f,%+.2f) gamepadDrives=%d" % [
			op.player_id, ai_s, kind_s,
			str(op.is_gamepad_input()),
			str(op.diag_using_mouse()),
			op.diag_aim_source_name(),
			aimv.x, aimv.y, movev.x, movev.y,
			rad_to_deg(op.aim_yaw), op.aim_direction.x, op.aim_direction.z,
			op.diag_aim_input_calls,
		])

	if cam != null:
		lines.append("CAM: rot=%s pos=%s" % [str(cam.rotation_degrees), str(cam.global_position)])

	_label.text = "\n".join(lines)

func _find_input_manager() -> InputManager:
	for node: Node in get_tree().get_nodes_in_group("input_manager"):
		if node is InputManager:
			return node as InputManager
	for node: Node in get_tree().root.get_children():
		if node is InputManager:
			return node as InputManager
	var found: Array[InputManager] = []
	_find_input_manager_recursive(get_tree().root, found)
	return found[0] if found.size() > 0 else null

func _find_input_manager_recursive(node: Node, found: Array[InputManager]) -> void:
	if found.size() > 0:
		return
	for child: Node in node.get_children():
		if child is InputManager:
			found.append(child as InputManager)
			return
		_find_input_manager_recursive(child, found)

func _find_camera() -> CameraController:
	for node: Node in get_tree().get_nodes_in_group("camera_controller"):
		if node is CameraController:
			return node as CameraController
	for node: Node in get_tree().root.get_children():
		if node is CameraController:
			return node as CameraController
	var found: Array[CameraController] = []
	_find_camera_recursive(get_tree().root, found)
	return found[0] if found.size() > 0 else null

func _find_camera_recursive(node: Node, found: Array[CameraController]) -> void:
	if found.size() > 0:
		return
	for child: Node in node.get_children():
		if child is CameraController:
			found.append(child as CameraController)
			return
		_find_camera_recursive(child, found)
