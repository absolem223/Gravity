# test_menu_flow.gd
# Technical Rationale: Headless validation of the definitive menu architecture that
# does NOT depend on autoload global identifiers (unavailable to the `-s` compiler).
# Uses UIScreen subclasses that are config-agnostic to exercise the router (push/pop/
# state preservation) which is the backbone of the whole menu system. The real screens
# themselves are validated by booting the scene tree in normal mode.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	call_deferred("run_test")

class DummyScreen extends UIScreen:
	var tag: String = ""
	func _init(t: String) -> void:
		tag = t
	func _ready() -> void:
		super._ready()

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

var _test_result: int = -1
func _on_test_confirm(choice: bool) -> void:
	_test_result = 1 if choice else 0

func run_test() -> void:
	print("== MENU ROUTER TEST ==")
	var stack: UIScreenStack = UIScreenStack.new()
	get_root().add_child(stack)

	var a: DummyScreen = DummyScreen.new("A")
	stack.push(a)
	_check(stack.top() == a, "push shows first screen")
	_check(not stack.back_enabled(), "single screen disables back")

	var b: DummyScreen = DummyScreen.new("B")
	stack.push(b)
	_check(stack.top() == b, "push shows topmost")
	_check(stack.back_enabled(), "back enabled with 2 screens")
	_check(not a.visible, "previous screen hidden while top shown")

	stack.pop()
	_check(stack.top() == a and a.visible, "pop restores previous screen")
	_check(not stack.top().visible == false, "top restored visible")

	stack.pop()
	_check(stack.top() == null, "empty stack after last pop")
	stack.pop()
	_check(stack.back_enabled() == false, "pop on empty stack is a no-op")

	# Replace swaps the top screen.
	stack.push(a)
	var c: DummyScreen = DummyScreen.new("C")
	stack.replace(c)
	_check(stack.top() == c, "replace places the new screen on top")
	await physics_frame
	_check(not is_instance_valid(a), "replace frees the old top")

	stack.queue_free()
	for i in 2:
		await physics_frame

	# ConfirmDialog fires confirmed(true) via Sí and confirmed(false) via No.
	var cd: ConfirmDialog = ConfirmDialog.new()
	get_root().add_child(cd)
	await physics_frame
	_test_result = -1
	cd.confirmed.connect(_on_test_confirm)
	cd.open("¿Reasignar?")
	await physics_frame
	_check(cd.visible == true, "ConfirmDialog opens and shows message")
	_check(_test_result == -1, "no signal before confirming")

	# Sí button → confirmed(true).
	cd._close(true)
	await physics_frame
	_check(_test_result == 1, "Sí fires confirmed(true)")
	_check(cd.visible == false, "ConfirmDialog hid after confirm")

	# No button → confirmed(false).
	_test_result = -1
	cd.open("¿Otra vez?")
	await physics_frame
	cd._close(false)
	await physics_frame
	_check(_test_result == 0, "No fires confirmed(false)")

	cd.queue_free()

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)