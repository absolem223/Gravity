# probe_joypad_axes_windowed.gd
# WINDOWED-only diagnostic instrument (run WITHOUT --headless; headless never
# enumerates joypads). Does NOT modify or consult any game code: it reads raw
# joypad axes 0-7 directly for ~60 seconds and prints ONLY when a value changes
# by >= 0.05, so the user can move each stick at their own pace with no prompts.
# Produces an AXIS ACTIVITY SUMMARY (min/max/peak per axis 0-7).
# Purpose: determine which physical axis the PS3 Controller reports for RIGHT-Y.
extends SceneTree

const AXIS_COUNT: int = 8
const CHANGE_THRESHOLD: float = 0.05
const DURATION_MSEC: int = 60000

var _start_msec: int = 0
var _last_print: Array[float] = []
var _min: Array[float] = []
var _max: Array[float] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if root != null:
		root.title = "PS3 AXIS PROBE (60s)"
	print("== WINDOWED JOYPAD AXIS PROBE ==")
	print("display server: ", DisplayServer.get_name())

	## 1) Wait for a connected joypad (poll up to ~15s).
	var pads: Array = []
	var waited: int = 0
	while pads.is_empty() and waited < 900:
		pads = Input.get_connected_joypads()
		await physics_frame
		waited += 1
	if pads.is_empty():
		print("JOYPAD_NOT_DETECTED")
		quit(1)
		return
	var dev: int = int(pads[0])
	var info: Dictionary = Input.get_joy_info(dev)
	print("pad id=%d name='%s' vendor=%d product=%d (pads=%s)" % [
		dev, Input.get_joy_name(dev), int(info.get("vendor_id", 0)), int(info.get("product_id", 0)), str(pads)])

	## 2) Seed baseline and min/max trackers.
	for a: int in range(AXIS_COUNT):
		_last_print.append(Input.get_joy_axis(dev, a))
		_min.append(0.0)
		_max.append(0.0)

	print("")
	print("CAPTURE STARTED: reading axes 0-7 for ~60s.")
	print("Keep all sticks centered for a few seconds, then move ONLY the RIGHT")
	print("stick at your own pace: LEFT -> center -> RIGHT -> center -> UP ->")
	print("center -> DOWN -> center -> diagonals. Lines print only when an axis")
	print("moves >= %.2f." % CHANGE_THRESHOLD)
	print("")

	_start_msec = Time.get_ticks_msec()
	while Time.get_ticks_msec() - _start_msec < DURATION_MSEC:
		var any_change: bool = false
		var moved: Array[String] = []
		var cur: Array[float] = []
		for a: int in range(AXIS_COUNT):
			var v: float = Input.get_joy_axis(dev, a)
			cur.append(v)
			_min[a] = minf(_min[a], v)
			_max[a] = maxf(_max[a], v)
			if absf(v - _last_print[a]) >= CHANGE_THRESHOLD:
				any_change = true
				moved.append("a%d(%.2f)" % [a, v])
		if any_change:
			var elapsed: float = float(Time.get_ticks_msec() - _start_msec) / 1000.0
			var line: String = "[t=%5.1fs] dev=%d " % [elapsed, dev]
			for a: int in range(AXIS_COUNT):
				line += "a%d=%.2f " % [a, cur[a]]
			line += "MOVED: %s" % ", ".join(moved)
			print(line)
			_last_print = cur
		await physics_frame

	## 3) Summary.
	print("")
	print("--- AXIS ACTIVITY SUMMARY (%.1fs) ---" % (float(DURATION_MSEC) / 1000.0))
	var active: Array[String] = []
	for a: int in range(AXIS_COUNT):
		var peak: float = maxf(absf(_min[a]), absf(_max[a]))
		var tag: String = "  [ACTIVE]" if peak > 0.5 else "  [quiet/noise]"
		print("  a%d: min=%+.3f max=%+.3f peak=%.3f%s" % [a, _min[a], _max[a], peak, tag])
		if peak > 0.5:
			active.append("a%d" % a)
	print("axes with real deflection (peak > 0.5): %s" % (", ".join(active) if not active.is_empty() else "NONE"))
	print("")
	print("OBSERVATION ONLY - no mapping change is made or implied.")
	print("PROBE_DONE")
	quit(0)