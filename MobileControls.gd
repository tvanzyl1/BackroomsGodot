class_name MobileControls
extends Control

signal move_changed(value: Vector2)
signal look_changed(delta: Vector2)
signal attack_pressed
signal flashlight_pressed
signal sprint_changed(pressed: bool)

var move_touch_id: int = -1
var look_touch_id: int = -1
var move_value := Vector2.ZERO
var move_origin := Vector2.ZERO
var move_radius: float = 72.0
var action_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_action_buttons()
	_layout_action_buttons()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_action_buttons()
		queue_redraw()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_touch_state()

func _layout_action_buttons() -> void:
	if action_buttons.size() < 3:
		return
	action_buttons[0].position = Vector2(size.x - 154.0, size.y - 174.0)
	action_buttons[1].position = Vector2(size.x - 220.0, size.y - 84.0)
	action_buttons[2].position = Vector2(size.x - 112.0, size.y - 84.0)

func _create_action_buttons() -> void:
	var attack_button := _create_button("ATTACK", Vector2(118.0, 118.0))
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	var flashlight_button := _create_button("LIGHT", Vector2(92.0, 56.0))
	flashlight_button.pressed.connect(func() -> void: flashlight_pressed.emit())
	var sprint_button := _create_button("RUN", Vector2(92.0, 56.0))
	sprint_button.button_down.connect(func() -> void: sprint_changed.emit(true))
	sprint_button.button_up.connect(func() -> void: sprint_changed.emit(false))
	action_buttons = [attack_button, flashlight_button, sprint_button]

func _create_button(label: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_action_button_position(event.position):
			return
		if move_touch_id == -1 and event.position.x < size.x * 0.45:
			move_touch_id = event.index
			move_origin = event.position
			_set_move(event.position)
		elif look_touch_id == -1:
			look_touch_id = event.index
	else:
		if event.index == move_touch_id:
			_reset_move_state()
		elif event.index == look_touch_id:
			look_touch_id = -1

func _reset_touch_state() -> void:
	_reset_move_state()
	look_touch_id = -1

func _reset_move_state() -> void:
	move_touch_id = -1
	move_value = Vector2.ZERO
	move_changed.emit(move_value)
	queue_redraw()

func _is_action_button_position(position: Vector2) -> bool:
	for button in action_buttons:
		if Rect2(button.position, button.size).has_point(position):
			return true
	return false

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_id:
		_set_move(event.position)
	elif event.index == look_touch_id:
		look_changed.emit(event.relative)

func _set_move(position: Vector2) -> void:
	var offset := position - move_origin
	move_value = offset.limit_length(move_radius) / move_radius
	move_changed.emit(move_value)
	queue_redraw()

func _draw() -> void:
	var joystick_center := move_origin if move_touch_id != -1 else Vector2(maxf(112.0, size.x * 0.16), size.y - 126.0)
	draw_circle(joystick_center, move_radius + 14.0, Color(0.02, 0.02, 0.02, 0.28))
	draw_circle(joystick_center, move_radius, Color(0.85, 0.75, 0.52, 0.16))
	var knob_position := joystick_center + move_value * move_radius
	draw_circle(knob_position, 30.0, Color(1.0, 0.82, 0.42, 0.48))
