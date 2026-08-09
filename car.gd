extends VehicleBody3D

@export var max_engine_force: float = 3000.0
@export var max_steering_angle: float = 0.45
@export var handbrake_brake_force: float = 150.0

@export var speed_label: Label
@export var velocity_vector_scale: float = 1.0

# Настройки заноса
@export var base_friction_slip: float = 5.5
@export var max_slip_angle_degrees: float = 15.0
@export var slip_effect_strength: float = 0.6

var steering_target: float = 0.0

var wheels: Array = []
var front_wheels: Array = []
var rear_wheels: Array = []


func _ready():
	# Собираем колёса автоматически
	for child in get_children():
		if child is VehicleWheel3D:
			wheels.append(child)

			# ВАЖНО:
			# use_as_steering и use_as_traction используем как "метки"
			if child.use_as_steering:
				front_wheels.append(child)
			else:
				rear_wheels.append(child)

	# Отключаем встроенную магию Godot
	for w in wheels:
		w.use_as_traction = false
		w.use_as_steering = false



func _physics_process(delta: float):

	var vel: Vector3 = linear_velocity
	var speed: float = vel.length()
	var speed_kph: float = speed * 3.6
	# --- Вектор скорости (дебаг) ---
	var start: Vector3 = global_position
	var arrow_length: float = max(speed_kph * velocity_vector_scale, 0.5)
	var end: Vector3 = start + vel.normalized() * arrow_length
	var color: Color = Color.RED if speed_kph > 5.0 else Color.GREEN
	DebugDraw3D.draw_arrow(start, end, color, 0.1)

	var forward_dir: Vector3 = -global_transform.basis.z
	var right_dir: Vector3 = global_transform.basis.x

	var forward_speed: float = vel.dot(forward_dir)
	var side_speed: float = vel.dot(right_dir)

	# =====================================================
	# 🧠 SLIP ANGLE
	# =====================================================
	var slip_angle: float = atan2(side_speed, max(abs(forward_speed), 0.1))
	var slip_deg: float = abs(rad_to_deg(slip_angle))

	var slip_norm: float = clamp(
		inverse_lerp(0.0, max_slip_angle_degrees, slip_deg),
		0.0,
		1.0
	)

	# =====================================================
	# 🎮 INPUT
	# =====================================================
	var throttle := 0.0
	var brake_input := 0.0
	var steer_input := 0.0
	var handbrake := Input.is_action_pressed("ui_accept")

	if Input.is_action_pressed("ui_up"):
		throttle = 1.0
	elif Input.is_action_pressed("ui_down"):
		throttle = -0.5

	if Input.is_action_pressed("ui_left"):
		steer_input += 1.0
	if Input.is_action_pressed("ui_right"):
		steer_input -= 1.0


	# =====================================================
	# ⚡ ENGINE (с учётом заноса)
	# =====================================================
	var engine_force = throttle * max_engine_force

	# Потеря тяги при заносе
	#var traction_loss = slip_norm * slip_effect_strength
#
	## На газу усиливаем занос (RWD эффект)
	#if throttle > 0:
		#traction_loss += 0.3 * throttle
#
	#engine_force *= (1.0 - clamp(traction_loss, 0.0, 0.9))


	# =====================================================
	# 🛞 РАЗДЕЛЬНОЕ СЦЕПЛЕНИЕ
	# =====================================================
	var speed_factor = clamp(speed / 30.0, 0.0, 1.0)

	# Перед — стабильнее
	var front_slip = base_friction_slip * (
		1.0
		- slip_norm * 0.2
		- speed_factor * 0.1
	)

	# Зад — более "дрифтовый"
	var rear_slip = base_friction_slip * (
		1.0
		- slip_norm * 0.4
		- speed_factor * 0.15
	)

	# Газ → ещё меньше сцепления сзади
	rear_slip *= (1.0 - throttle * 0.1)

	front_slip = clamp(front_slip, 0.5, 5.0)
	rear_slip = clamp(rear_slip, 0.3, 5.0)

	for w in front_wheels:
		w.wheel_friction_slip = front_slip

	for w in rear_wheels:
		w.wheel_friction_slip = rear_slip


	# =====================================================
	# 🔥 ДВИЖОК (RWD)
	# =====================================================
	for w in rear_wheels:
		w.engine_force = engine_force

	for w in front_wheels:
		w.engine_force = 0.0


	# =====================================================
	# 🛑 ТОРМОЗ + ABS
	# =====================================================
	var brake_force = 0.0

	#if throttle < 0:
		#brake_force = abs(throttle) * 200.0

	# простой ABS: если сильно скользим — ослабляем тормоз
	#if slip_norm > 0.7:
		#brake_force *= 0.5

	#for w in wheels:
		#w.brake = brake_force


	# =====================================================
	# 🚗 РУЧНИК
	# =====================================================
	if handbrake:
		for w in rear_wheels:
			w.brake = handbrake_brake_force
			w.wheel_friction_slip *= 0.5  # резкий срыв


	# =====================================================
	# 🧭 РУЛЬ
	# =====================================================
	var steer_limit = lerp(
		max_steering_angle,
		0.15,
		speed_factor
	)

	var target_steer = steer_input * steer_limit
	steering_target = lerp(steering_target, target_steer, delta * 8.0)

	for w in front_wheels:
		w.steering = steering_target


	# =====================================================
	# 🧲 БОКОВОЕ ГАШЕНИЕ (очень важно)
	# =====================================================
	# имитирует реальную работу шин
	var lateral_damping = 4.0 + (1.0 - slip_norm) * 6.0

	var lateral_velocity = right_dir * side_speed

	var lateral_force = -right_dir * side_speed * lateral_damping

	for w in wheels:
		var force_pos = w.global_position - global_position
		apply_force(lateral_force, force_pos)

	# =====================================================
	# UI
	# =====================================================
	if speed_label:
		speed_label.text = "%d км/ч" % speed_kph
