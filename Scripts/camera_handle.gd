extends Node3D

@export var node_to_follow: Node3D
@export_range(0.0, 1.0) var mouse_sens: = 0.25
@export_range(0.0, 10.0) var stick_sens: = 2.5

var _camera_input_direction := Vector2.ZERO
var active := true

func _input(event: InputEvent) -> void:
	if not active: return
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	var is_camera_mouse_motion := (
		event is InputEventMouseMotion and
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_mouse_motion:
		_camera_input_direction = event.screen_relative * mouse_sens
		_camera_input_direction.y *= -1

func _physics_process(delta: float) -> void:
	if not active or not node_to_follow: return
	position = node_to_follow.position
	var gamepad_input = Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_down", "look_up")) * stick_sens
	if gamepad_input:
		_camera_input_direction = gamepad_input

	rotation.z += _camera_input_direction.y * delta
	rotation.y -= _camera_input_direction.x * delta

	rotation.z = clamp(rotation.z, -PI / 2, PI / 2)
	_camera_input_direction = Vector2.ZERO
