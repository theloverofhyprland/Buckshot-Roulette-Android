extends Node

# On-screen controls for touch devices.
# The rest of the game already works via Godot's touch->mouse emulation;
# this only adds a movement stick (multiplayer / free roam) and A/B keys
# (CRT console uses ui_accept / ui_cancel).

var layer: CanvasLayer
var root: Control
var stick: Control
var dragging := false
var stick_center := Vector2(110, 430)
var knob := Vector2.ZERO
var actions = ["move_forward", "move_backwards", "move_left", "move_right"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	stick = Control.new()
	stick.position = Vector2(20, 340)
	stick.size = Vector2(180, 180)
	stick.mouse_filter = Control.MOUSE_FILTER_STOP
	stick.draw.connect(_draw_stick)
	stick.gui_input.connect(_stick_input)
	root.add_child(stick)

	_make_key("A", Vector2(866, 440), "ui_accept")
	_make_key("B", Vector2(786, 468), "ui_cancel")

func _make_key(text: String, pos: Vector2, action: String):
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(72, 72)
	b.modulate = Color(1, 1, 1, 0.42)
	b.add_theme_font_size_override("font_size", 30)
	b.button_down.connect(func(): _action(action, true))
	b.button_up.connect(func(): _action(action, false))
	root.add_child(b)

func _action(action: String, pressed: bool):
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _stick_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			_update_stick(event.position)
		else:
			dragging = false
			_reset_stick()
	elif event is InputEventMouseMotion and dragging:
		_update_stick(event.position)

func _update_stick(p: Vector2):
	var v: Vector2 = p - Vector2(90, 90)
	if v.length() > 80: v = v.normalized() * 80
	knob = v
	var n := v / 80.0
	Input.action_press("move_right", max(n.x, 0.0))
	Input.action_press("move_left", max(-n.x, 0.0))
	Input.action_press("move_backwards", max(n.y, 0.0))
	Input.action_press("move_forward", max(-n.y, 0.0))
	stick.queue_redraw()

func _reset_stick():
	knob = Vector2.ZERO
	for a in actions: Input.action_release(a)
	stick.queue_redraw()

func _draw_stick():
	stick.draw_circle(Vector2(90, 90), 80, Color(1, 1, 1, 0.10))
	stick.draw_arc(Vector2(90, 90), 80, 0, TAU, 48, Color(1, 1, 1, 0.30), 3.0)
	stick.draw_circle(Vector2(90, 90) + knob, 28, Color(1, 1, 1, 0.28))
