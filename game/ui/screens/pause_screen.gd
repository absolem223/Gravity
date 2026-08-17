# pause_screen.gd
# Technical Rationale: In-match pause menu (PMSG). Reuses the UIScreenStack router
# so "Pause -> Settings -> Controls -> Back -> Pause" traverses the SAME screens
# the main menu uses, with zero duplicated code. The active Match stays alive:
# resuming only clears SceneTree.paused — the Match node is never recreated.
# The overlay is hosted in a CanvasLayer with PROCESS_MODE_ALWAYS so the menu stays
# interactive while the simulation is paused.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name PauseScreen
extends UIScreen

## Callable invoked by "Volver a la partida" (unpauses + hides the overlay).
var resume_callback: Callable = Callable()

func _init(resume: Callable = Callable()) -> void:
	resume_callback = resume

func _ready() -> void:
	super._ready()
	screen_title = "Pausa"
	_build()
	focus_first()

func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_right", 96)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	box.add_child(MenuFactory.make_title("PAUSA"))
	box.add_child(MenuFactory.make_hint("El partido sigue activo. Volvé cuando quieras."))

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	box.add_child(MenuFactory.make_button("Volver a la partida", _on_resume))
	box.add_child(MenuFactory.make_button("Ajustes", _on_settings))
	box.add_child(MenuFactory.make_button("Controles", _on_controls))
	box.add_child(MenuFactory.make_button("Reiniciar partida", _on_restart))
	box.add_child(MenuFactory.make_button("Salir al menú", _on_quit))

func _on_resume() -> void:
	_do_resume()

func _do_resume() -> void:
	if resume_callback.is_valid():
		resume_callback.call()

func _on_settings() -> void:
	push(SettingsScreen.new())

func _on_controls() -> void:
	push(PlayersConfigScreen.new())

func _on_restart() -> void:
	if resume_callback.is_valid():
		resume_callback.call()
	# Deferred so the unpause completes before the scene swaps.
	get_tree().call_deferred("change_scene_to_file", GameConfig.MATCH_SCENE_PATH)

func _on_quit() -> void:
	if resume_callback.is_valid():
		resume_callback.call()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")

## ESC at the pause root resumes; sub-screens (Settings/Controls) pop normally
## via UIScreen back handling.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		var router: UIScreenStack = get_router()
		if router == null or not router.back_enabled():
			get_viewport().set_input_as_handled()
			_do_resume()