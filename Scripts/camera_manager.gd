extends Node3D

@export var chase_controller: Node3D          # узел с camera_chase.gd
@export var handle_controller: Node3D         # узел с camera_handle.gd
@export var chase_camera: Camera3D            # дочерняя камера ChaseController
@export var handle_camera: Camera3D           # дочерняя камера HandleController
@export var node_to_follow: RigidBody3D

@export var idle_timeout: float = 2.0

enum Mode { CHASE, HANDLE }
var current_mode: Mode = Mode.CHASE
var idle_timer: float = 0.0

func _ready() -> void:
	chase_controller.node_to_follow = node_to_follow
	handle_controller.node_to_follow = node_to_follow
	_switch_to_chase()

func _input(event: InputEvent) -> void:
	# Захват/освобождение мыши (менеджер управляет этим глобально)
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Активация ручного режима по движению мыши
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_switch_to_handle()
		idle_timer = 0.0

func _physics_process(delta: float) -> void:
	# Геймпад
	var gamepad := Vector2(
		Input.get_axis("look_left", "look_right"),
		Input.get_axis("look_down", "look_up")
	)
	if gamepad.length() > 0.1:
		_switch_to_handle()
		idle_timer = 0.0

	# Таймер бездействия
	if current_mode == Mode.HANDLE:
		idle_timer += delta
		if idle_timer >= idle_timeout:
			_switch_to_chase()

func _switch_to_handle() -> void:
	if current_mode == Mode.HANDLE: return
	current_mode = Mode.HANDLE

	# Отключаем chase-камеру и скрипт
	chase_camera.current = false
	chase_controller.active = false

	# Включаем handle-камеру и скрипт
	handle_camera.current = true
	handle_controller.active = true

	idle_timer = 0.0

func _switch_to_chase() -> void:
	if current_mode == Mode.CHASE: return
	current_mode = Mode.CHASE

	handle_camera.current = false
	handle_controller.active = false

	chase_camera.current = true
	chase_controller.active = true

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
