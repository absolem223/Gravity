# main_menu.gd
# Technical Rationale: Root scene shell (MC_MAIN applied). Installs the UIScreenStack
# router and pushes the first screen. All navigation lives in the UIScreenStack; this
# script only boots the flow. Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name MainMenu
extends Control

var _stack: UIScreenStack = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuFactory.make_background())

	_stack = UIScreenStack.new()
	add_child(_stack)
	_stack.push(MainScreen.new())

	GameConfig.apply_runtime_settings()