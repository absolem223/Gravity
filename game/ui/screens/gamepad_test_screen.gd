# gamepad_test_screen.gd
# Technical Rationale: Interactive, DIAGNOSTIC-ONLY gamepad inspector opened from
# the controls settings. Reads the raw Godot joystick API directly
# (Input.get_connected_joypads / get_joy_axis / get_joy_button / get_joy_info) so it
# shows EXACTLY what the engine receives per axis and button — it never reads
# InputMap, actions, InputProfile or gameplay state, and never writes anything.
# Includes a manual, step-by-step guided procedure (left/right stick, up/down/
# left/right) with NO timed windows: the user advances by pressing a button, and
# each step records initial/min/max/final values plus which axes changed. Stick
# visuals are NOT hardcoded to "axis 2/3 = right X/Y": each pad has editable axis
# selectors and the guide reports the real axes that move for each stick.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name GamepadTestScreen
extends UIScreen

const AXIS_COUNT: int = 16
const BUTTON_COUNT: int = 32
const ACTIVITY_THRESHOLD: float = 0.05
const CHANGE_THRESHOLD: float = 0.1
const MAX_LOG: int = 200

const GUIDE_STEPS: Array[Dictionary] = [
	{"stick": "Izquierdo", "dir": "ARRIBA"},
	{"stick": "Izquierdo", "dir": "ABAJO"},
	{"stick": "Izquierdo", "dir": "IZQUIERDA"},
	{"stick": "Izquierdo", "dir": "DERECHA"},
	{"stick": "Derecho", "dir": "ARRIBA"},
	{"stick": "Derecho", "dir": "ABAJO"},
	{"stick": "Derecho", "dir": "IZQUIERDA"},
	{"stick": "Derecho", "dir": "DERECHA"},
]

const BUTTON_LABELS: Dictionary = {
	0: "A", 1: "B", 2: "X", 3: "Y",
	4: "Back", 5: "Guide", 6: "Start", 7: "LS", 8: "RS",
	9: "L1", 10: "R1",
	11: "D-Pad ↑", 12: "D-Pad ↓", 13: "D-Pad ←", 14: "D-Pad →",
}

var _dev: int = -1
var _dev_names: Array[int] = []

var _dev_option: OptionButton = null
var _dev_info: Label = null
var _axis_labels: Array[Label] = []
var _button_labels: Array[Label] = []
var _log_box: VBoxContainer = null
var _log_scroll: ScrollContainer = null
var _log_count: int = 0

var _lpad: StickPad = null
var _rpad: StickPad = null

var _guide_status: Label = null
var _guide_live: Label = null
var _records_box: VBoxContainer = null
var _guide_summary: Label = null
var _start_btn: Button = null

var _guide_idx: int = -1
var _records: Array[Dictionary] = []
var _step_initial: Array[float] = []
var _step_min: Array[float] = []
var _step_max: Array[float] = []

var _prev_axis: Array[float] = []
var _prev_btns: Array[bool] = []
var _axis_seen: Array[bool] = []

func _ready() -> void:
	super._ready()
	screen_title = "Diagnóstico de Gamepad"
	_build()
	_refresh_device_list()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if _start_btn != null:
		_start_btn.call_deferred("grab_focus")

func _process(_delta: float) -> void:
	if _dev < 0 or not is_visible_in_tree():
		return
	_refresh_axes()
	_refresh_buttons()
	_update_pads()
	_update_step_live()

## ── Build ────────────────────────────────────────────────────────────────────
func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(MenuFactory.make_button("Volver", pop, 140, 44))
	var title: Label = MenuFactory.make_title("Diagnóstico de Gamepad")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	outer.add_child(header)

	outer.add_child(MenuFactory.make_hint(
		"Solo lectura: muestra en tiempo real lo que Godot recibe del control y registra cada paso de la guía. " +
		"No modifica acciones, mappings, deadzones ni gameplay."))

	outer.add_child(_build_guide_top())

	var main_scroll: ScrollContainer = ScrollContainer.new()
	main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(main_scroll)

	var main_box: HBoxContainer = HBoxContainer.new()
	main_box.add_theme_constant_override("separation", 32)
	main_scroll.add_child(main_box)

	main_box.add_child(_build_left())
	main_box.add_child(_build_right())

## Full-width guide header, always visible above the columns.
func _build_guide_top() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	box.add_child(MenuFactory.make_section("Guía paso a paso (manual)"))

	_guide_status = MenuFactory.make_label(
		"Presioná «Iniciar guía» y seguí las instrucciones, avanzando vos mismo.", 16, MenuFactory.COLOR_TEXT)
	_guide_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_guide_status)

	_guide_live = MenuFactory.make_label("", 15, MenuFactory.COLOR_MUTED)
	_guide_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_guide_live)

	var guide_row: HBoxContainer = HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 10)
	_start_btn = MenuFactory.make_button("Iniciar guía", _start_guide, 170, 48)
	guide_row.add_child(_start_btn)
	guide_row.add_child(MenuFactory.make_button("← Anterior", _go_back, 150, 48))
	guide_row.add_child(MenuFactory.make_button("Siguiente paso →", _advance_step, 210, 48))
	guide_row.add_child(MenuFactory.make_button("Reiniciar", _reset_guide, 140, 48))
	box.add_child(guide_row)

	return box

## Left column: device, live axes, buttons, activity log.
func _build_left() -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(680, 0)

	col.add_child(MenuFactory.make_section("Dispositivo"))

	var dev_row: HBoxContainer = HBoxContainer.new()
	dev_row.add_theme_constant_override("separation", 10)
	_dev_option = OptionButton.new()
	_dev_option.custom_minimum_size = Vector2(420, 40)
	_dev_option.item_selected.connect(_on_device_selected)
	dev_row.add_child(_dev_option)
	col.add_child(dev_row)

	_dev_info = MenuFactory.make_label("", 15, MenuFactory.COLOR_MUTED)
	_dev_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_dev_info)

	col.add_child(MenuFactory.make_section("Ejes en vivo"))

	var axis_grid: GridContainer = GridContainer.new()
	axis_grid.columns = 4
	axis_grid.add_theme_constant_override("h_separation", 18)
	axis_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(axis_grid)
	for a: int in range(AXIS_COUNT):
		var l: Label = MenuFactory.make_label("Eje %2d: +0.000" % a, 15, MenuFactory.COLOR_MUTED)
		axis_grid.add_child(l)
		_axis_labels.append(l)
		_prev_axis.append(0.0)
		_axis_seen.append(false)

	col.add_child(MenuFactory.make_section("Botones"))

	var btn_grid: GridContainer = GridContainer.new()
	btn_grid.columns = 4
	btn_grid.add_theme_constant_override("h_separation", 18)
	btn_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(btn_grid)
	for b: int in range(BUTTON_COUNT):
		var l: Label = MenuFactory.make_label("%s · suelto" % _button_name(b), 14, MenuFactory.COLOR_MUTED)
		btn_grid.add_child(l)
		_button_labels.append(l)
		_prev_btns.append(false)

	col.add_child(MenuFactory.make_section("Historial de actividad"))

	_log_scroll = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(0, 220)
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

	return col

## Right column: guided records/summary + stick pads.
func _build_right() -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_records_box = VBoxContainer.new()
	_records_box.add_theme_constant_override("separation", 3)
	col.add_child(_records_box)

	_guide_summary = MenuFactory.make_label("", 15, MenuFactory.COLOR_TEXT)
	_guide_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_guide_summary)

	col.add_child(MenuFactory.make_section("Sticks (ejes editables, sin suponer mapeo)"))

	var pads_row: HBoxContainer = HBoxContainer.new()
	pads_row.add_theme_constant_override("separation", 24)
	col.add_child(pads_row)

	_lpad = StickPad.new("Stick Izquierdo")
	pads_row.add_child(_make_pad_column(_lpad, 0, 1, true))
	_rpad = StickPad.new("Stick Derecho")
	pads_row.add_child(_make_pad_column(_rpad, 2, 3, false))

	col.add_child(MenuFactory.make_hint(
		"Cada pad usa los ejes que elijas acá (sin asumir 0/1 = izquierdo ni 2/3 = derecho). " +
		"Usá la guía para confirmar qué ejes mueve cada stick en este control."))

	return col

func _make_pad_column(pad: StickPad, x_axis: int, y_axis: int, _left: bool) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(pad)
	box.add_child(_make_axis_selector("Eje X", pad, true, x_axis))
	box.add_child(_make_axis_selector("Eje Y", pad, false, y_axis))
	return box

func _make_axis_selector(label_text: String, pad: StickPad, is_x: bool, default_axis: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl: Label = MenuFactory.make_label(label_text, 14, MenuFactory.COLOR_MUTED)
	lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(lbl)
	var opt: OptionButton = OptionButton.new()
	opt.custom_minimum_size = Vector2(120, 34)
	for a: int in range(AXIS_COUNT):
		opt.add_item("Eje %d" % a, a)
	opt.select(default_axis)
	opt.item_selected.connect(func(idx: int) -> void:
		var axis: int = opt.get_item_id(idx)
		if is_x:
			pad.set_axes(axis, pad.y_axis)
		else:
			pad.set_axes(pad.x_axis, axis))
	row.add_child(opt)
	return row

## ── Device handling ─────────────────────────────────────────────────────────
func _refresh_device_list() -> void:
	_dev_option.clear()
	_dev_names.clear()
	var pads: Array[int] = Input.get_connected_joypads()
	for p: int in pads:
		_dev_names.append(p)
		var nm: String = Input.get_joy_name(p)
		_dev_option.add_item("Joystick %d — %s (dev %d)" % [p + 1, nm if not nm.is_empty() else "Control", p], p)
	var has: bool = not pads.is_empty()
	_dev_option.disabled = not has
	if has:
		_dev_option.select(0)
		_select_device(pads[0])
	else:
		_select_device(-1)

func _on_device_selected(idx: int) -> void:
	if idx >= 0 and idx < _dev_option.item_count:
		_select_device(_dev_option.get_item_id(idx))

func _select_device(dev: int) -> void:
	_dev = dev
	_clear_activity_log()
	for a: int in range(AXIS_COUNT):
		_prev_axis[a] = 0.0
		_axis_seen[a] = false
		_axis_labels[a].text = "Eje %2d: +0.000" % a
		_axis_labels[a].modulate = MenuFactory.COLOR_MUTED
	for b: int in range(BUTTON_COUNT):
		_prev_btns[b] = false
		_button_labels[b].text = "%s · suelto" % _button_name(b)
		_button_labels[b].modulate = MenuFactory.COLOR_MUTED
	if dev < 0:
		_dev_info.text = "Sin joystick conectado."
		_reset_guide()
		return
	var info: Dictionary = Input.get_joy_info(dev)
	_dev_info.text = (
		"Nombre: %s    Dev ID: %d\n"
		+ "Vendor: %s    Producto: %s\n"
		+ "Ejes con actividad detectada: %d") % [
			Input.get_joy_name(dev), dev,
			_str(info.get("vendor_id", "?")), _str(info.get("product_id", "?")),
			0]
	_log("Dispositivo: %s (dev %d)" % [Input.get_joy_name(dev), dev])

func _on_joy_connection_changed(_device_id: int, _connected: bool) -> void:
	_refresh_device_list()

func _button_name(b: int) -> String:
	if BUTTON_LABELS.has(b):
		return "B%d %s" % [b, str(BUTTON_LABELS[b])]
	return "B%d" % b

func _str(v: Variant) -> String:
	return str(v)

## ── Live refresh ────────────────────────────────────────────────────────────
func _refresh_axes() -> void:
	var active: int = 0
	for a: int in range(AXIS_COUNT):
		var v: float = Input.get_joy_axis(_dev, a)
		if absf(v) > ACTIVITY_THRESHOLD:
			_axis_seen[a] = true
		if _axis_seen[a]:
			active += 1
		_axis_labels[a].text = "Eje %2d: %+.3f" % [a, v]
		_axis_labels[a].modulate = Color(0.55, 0.95, 0.55) if absf(v) > ACTIVITY_THRESHOLD else MenuFactory.COLOR_MUTED
		if absf(v - _prev_axis[a]) >= ACTIVITY_THRESHOLD:
			_log("Eje %d → %+.3f" % [a, v])
			_prev_axis[a] = v
	_dev_info.text = (
		"Nombre: %s    Dev ID: %d\n"
		+ "Vendor: %s    Producto: %s\n"
		+ "Ejes con actividad detectada: %d") % [
			Input.get_joy_name(_dev), _dev,
			_str(Input.get_joy_info(_dev).get("vendor_id", "?")),
			_str(Input.get_joy_info(_dev).get("product_id", "?")),
			active]

func _refresh_buttons() -> void:
	for b: int in range(BUTTON_COUNT):
		var on: bool = Input.is_joy_button_pressed(_dev, b)
		if on != _prev_btns[b]:
			_prev_btns[b] = on
			_log("Botón %s → %s" % [_button_name(b), "PRESIONADO" if on else "liberado"])
		_button_labels[b].text = "%s · %s" % [_button_name(b), "PRESIONADO" if on else "suelto"]
		_button_labels[b].modulate = Color(0.55, 0.95, 0.55) if on else MenuFactory.COLOR_MUTED

func _update_pads() -> void:
	_lpad.set_values(Input.get_joy_axis(_dev, _lpad.x_axis), Input.get_joy_axis(_dev, _lpad.y_axis))
	_rpad.set_values(Input.get_joy_axis(_dev, _rpad.x_axis), Input.get_joy_axis(_dev, _rpad.y_axis))

## ── Guided procedure ────────────────────────────────────────────────────────
func _start_guide() -> void:
	if _dev < 0:
		_guide_status.text = "Conectá un joystick primero."
		return
	_records.clear()
	_clear_records_box()
	_guide_summary.text = ""
	_begin_step(0)

func _reset_guide() -> void:
	_records.clear()
	_clear_records_box()
	_guide_summary.text = ""
	_guide_idx = -1
	_guide_status.text = "Guía reiniciada. Presioná «Iniciar guía» para volver a empezar."
	_guide_live.text = ""

func _begin_step(idx: int) -> void:
	_guide_idx = idx
	_step_initial.clear()
	_step_min.clear()
	_step_max.clear()
	for a: int in range(AXIS_COUNT):
		var v: float = Input.get_joy_axis(_dev, a)
		_step_initial.append(v)
		_step_min.append(v)
		_step_max.append(v)
	var step: Dictionary = GUIDE_STEPS[idx]
	_guide_status.text = "Paso %d/%d — Stick %s, movelo hacia %s. Cuando termines, presioná «Siguiente paso →»." % [
		idx + 1, GUIDE_STEPS.size(), str(step["stick"]), str(step["dir"])]
	_guide_live.text = ""

func _update_step_live() -> void:
	if _guide_idx < 0 or _guide_idx >= GUIDE_STEPS.size():
		return
	var moved: Array[String] = []
	for a: int in range(AXIS_COUNT):
		var v: float = Input.get_joy_axis(_dev, a)
		_step_min[a] = minf(_step_min[a], v)
		_step_max[a] = maxf(_step_max[a], v)
		if absf(v - _step_initial[a]) >= CHANGE_THRESHOLD:
			moved.append("Eje %d: %+.3f" % [a, v])
	if moved.is_empty():
		_guide_live.text = "Aún no detecto movimiento. Mové el stick indicado."
	else:
		_guide_live.text = "Moviendo ahora: " + ", ".join(moved)

func _advance_step() -> void:
	if _guide_idx < 0 or _guide_idx >= GUIDE_STEPS.size():
		return
	_record_step()
	_guide_idx += 1
	if _guide_idx >= GUIDE_STEPS.size():
		_finish_guide()
	else:
		_begin_step(_guide_idx)

func _go_back() -> void:
	if _guide_idx <= 0 or _guide_idx > GUIDE_STEPS.size():
		return
	if _guide_idx < GUIDE_STEPS.size():
		_records.pop_back()
		_remove_last_record_row()
	_begin_step(_guide_idx - 1)

func _record_step() -> void:
	var step: Dictionary = GUIDE_STEPS[_guide_idx]
	var axes: Array[int] = []
	var details: Dictionary = {}
	for a: int in range(AXIS_COUNT):
		var fin: float = Input.get_joy_axis(_dev, a)
		var span: float = maxf(
			absf(_step_initial[a] - _step_min[a]),
			maxf(absf(_step_initial[a] - _step_max[a]), absf(_step_initial[a] - fin)))
		if span >= CHANGE_THRESHOLD:
			axes.append(a)
			details[a] = {
				"initial": _step_initial[a],
				"min": _step_min[a],
				"max": _step_max[a],
				"final": fin,
			}
	_records.append({"stick": str(step["stick"]), "dir": str(step["dir"]), "axes": axes, "details": details})
	var line: String = "Paso %d · Stick %s %s → " % [_guide_idx + 1, str(step["stick"]), str(step["dir"])]
	if axes.is_empty():
		line += "sin movimiento detectado"
	else:
		line += _axes_summary(axes, details)
	_records_box.add_child(MenuFactory.make_label(line, 14, MenuFactory.COLOR_TEXT))
	_log(line)

func _axes_summary(axes: Array[int], details: Dictionary) -> String:
	var parts: Array[String] = []
	for a: int in axes:
		var d: Dictionary = details[a] as Dictionary
		parts.append("Eje %d (ini %+.2f → fin %+.2f, min %+.2f, max %+.2f)" % [
			a, float(d["initial"]), float(d["final"]), float(d["min"]), float(d["max"])])
	return ", ".join(parts)

func _finish_guide() -> void:
	_guide_status.text = "Guía completada. Resumen abajo."
	_guide_live.text = ""
	var lines: Array[String] = ["== RESUMEN =="]
	for i: int in range(_records.size()):
		var r: Dictionary = _records[i]
		var axes: Array = r["axes"] as Array
		var line: String = "  %s %s → " % [str(r["stick"]), str(r["dir"])]
		if axes.is_empty():
			line += "sin movimiento"
		else:
			var parts: Array[String] = []
			for a: int in axes:
				var d: Dictionary = (r["details"] as Dictionary)[a] as Dictionary
				parts.append("Eje %d [%+.2f…%+.2f]" % [a, float(d["min"]), float(d["max"])])
			line += ", ".join(parts)
		lines.append(line)
	lines.append("")
	lines.append("== CONCLUSIÓN ==")
	var left_axes: Array[int] = _axes_union("Izquierdo")
	var right_axes: Array[int] = _axes_union("Derecho")
	lines.append("  Stick Izquierdo usa ejes: %s" % (_fmt_axes(left_axes) if not left_axes.is_empty() else "—"))
	lines.append("  Stick Derecho usa ejes: %s" % (_fmt_axes(right_axes) if not right_axes.is_empty() else "—"))
	if right_axes.size() == 1:
		lines.append("  El stick derecho tiene UN SOLO eje (sin vertical independiente).")
	elif right_axes.size() == 2:
		lines.append("  El stick derecho tiene dos ejes (horizontal + vertical).")
	elif right_axes.is_empty():
		lines.append("  No se detectó movimiento en el stick derecho.")
	_guide_summary.text = "\n".join(lines)

func _axes_union(stick: String) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for r: Dictionary in _records:
		if str(r["stick"]) != stick:
			continue
		for a: int in (r["axes"] as Array):
			if not seen.has(a):
				seen[a] = true
				out.append(a)
	return out

func _fmt_axes(axes: Array[int]) -> String:
	var parts: Array[String] = []
	for a: int in axes:
		parts.append("Eje %d" % a)
	return ", ".join(parts)

## ── Activity log ────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if _log_box == null:
		return
	var l: Label = MenuFactory.make_label(msg, 13, MenuFactory.COLOR_MUTED)
	_log_box.add_child(l)
	_log_count += 1
	if _log_count > MAX_LOG:
		var first: Node = _log_box.get_child(0)
		_log_box.remove_child(first)
		first.queue_free()
		_log_count -= 1
	call_deferred("_scroll_log_bottom")

func _scroll_log_bottom() -> void:
	if _log_scroll == null:
		return
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

func _clear_activity_log() -> void:
	if _log_box == null:
		return
	for child: Node in _log_box.get_children():
		_log_box.remove_child(child)
		child.queue_free()
	_log_count = 0

func _clear_records_box() -> void:
	if _records_box == null:
		return
	for child: Node in _records_box.get_children():
		_records_box.remove_child(child)
		child.queue_free()

func _remove_last_record_row() -> void:
	if _records_box != null and _records_box.get_child_count() > 0:
		var last: Node = _records_box.get_child(_records_box.get_child_count() - 1)
		_records_box.remove_child(last)
		last.queue_free()

## ── Stick pad widget ─────────────────────────────────────────────────────────
class StickPad extends Control:
	var x_axis: int = 0
	var y_axis: int = 1
	var _x: float = 0.0
	var _y: float = 0.0
	var _title: String = ""

	func _init(title_text: String) -> void:
		_title = title_text
		custom_minimum_size = Vector2(250, 210)

	func set_axes(ax: int, ay: int) -> void:
		x_axis = ax
		y_axis = ay
		queue_redraw()

	func set_values(vx: float, vy: float) -> void:
		_x = vx
		_y = vy
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
		var r: float = minf(size.x, size.y) * 0.42
		draw_circle(c, r, Color(0.16, 0.18, 0.24))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.4, 0.44, 0.5), 2.0)
		draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(0.3, 0.34, 0.4), 1.0)
		draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0.3, 0.34, 0.4), 1.0)
		var knob: Vector2 = c + Vector2(
			clampf(_x, -1.0, 1.0) * r * 0.8,
			-clampf(_y, -1.0, 1.0) * r * 0.8)
		var active: bool = maxf(absf(_x), absf(_y)) > 0.1
		draw_circle(knob, 14.0, Color(0.92, 0.58, 0.2, 0.9) if active else Color(0.5, 0.55, 0.62))
		draw_circle(knob, 6.0, Color(0.16, 0.18, 0.24))
		var font: Font = ThemeDB.fallback_font
		font.draw_string(get_canvas_item(), Vector2(8, 18), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 0.96))