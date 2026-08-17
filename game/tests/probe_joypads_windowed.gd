# probe_joypads_windowed.gd
# NON-HEADLESS runtime diagnostic: prints whether Godot can enumerate physical
# gamepads in a windowed process (headless mode never initializes joysticks).
# Auto-quits ~4s after launch. Run WITHOUT --headless.
extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("== WINDOWED JOYPAD ENUMERATION PROBE ==")
	print("display server: ", DisplayServer.get_name())
	var found: bool = false
	for i: int in range(240):
		var pads: Array = Input.get_connected_joypads()
		if i == 0:
			print("frame 0  pads: ", str(pads))
		if not pads.is_empty():
			found = true
			print("frame %d pads: %s" % [i, str(pads)])
			for p: int in pads:
				var info: Dictionary = Input.get_joy_info(p)
				var vid: int = info.get("vendor_id", 0) as int
				var pid: int = info.get("product_id", 0) as int
				print("  device %d: name='%s' vendor=%d product=%d" % [p, Input.get_joy_name(p), vid, pid])
				var axes: Array[float] = []
				for a: int in range(8):
					axes.append(Input.get_joy_axis(p, a))
				print("    axes 0..7:", str(axes))
			break
		await process_frame
	print("final pads: ", str(Input.get_connected_joypads()))
	print("JOYPAD_DETECTED" if found else "JOYPAD_NOT_DETECTED")
	quit(0)
