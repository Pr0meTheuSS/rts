class_name SuspensionZoom
extends Node3D

@export var is_drive: bool = false
@export var is_steer: bool = false
@export var mirror_wheel: bool = false
@export var to_debug: bool = false

var wheel_radius: float = 0.335
var wheel_inertia: float = 9.0
var rest_length: float = 0.18
var stiffness: float = 62000.0
var damping_compression: float = 4300.0
var damping_relaxation: float = 4700.0
var max_suspension_force: float = 18000.0
var mu_longitudinal: float = 1.35
var mu_lateral: float = 1.35
var slip_speed_reference: float = 1.0
var lateral_speed_reference: float = 1.0
var low_speed_enter: float = 0.45
var low_speed_exit: float = 1.5
var low_speed_blend_rate: float = 8.0
var low_speed_longitudinal_stiffness: float = 9000.0
var low_speed_lateral_stiffness: float = 11000.0
var longitudinal_slip_lateral_fade_start: float = 0.2
var longitudinal_slip_lateral_fade_end: float = 1.2
var force_rate_limit: float = 320000.0
var force_deadband: float = 4.0
var rolling_resistance_coefficient: float = 0.015
var wheel_viscous_drag: float = 0.02
var wheel_constant_drag: float = 0.0
var smoke_longitudinal_slip_start: float = 0.35
var smoke_longitudinal_slip_full: float = 1.8
var smoke_lateral_angle_start_deg: float = 10.0
var smoke_lateral_angle_full_deg: float = 35.0
var smoke_heat_capacity: float = 60000.0
var smoke_cooling_rate: float = 1.2
var smoke_visible_heat_start: float = 0.25
var smoke_visible_heat_full: float = 1.0
var brake_torque: float = 2400.0
var static_omega_threshold: float = 0.5
var use_tire_curves: bool = false
var longitudinal_tire_curve: Curve
var lateral_tire_curve: Curve
var pacejka_longitudinal_b: float = 10.0
var pacejka_longitudinal_c: float = 1.65
var pacejka_longitudinal_e: float = 0.97
var pacejka_lateral_b: float = 7.5
var pacejka_lateral_c: float = 1.35
var pacejka_lateral_e: float = 0.8

var _wheel_omega: float = 0.0
var _last_length: float = 0.0
var _grounded: bool = false
var _hub_point: Vector3 = Vector3.ZERO
var _contact_point: Vector3 = Vector3.ZERO
var _normal: Vector3 = Vector3.UP
var _long_dir: Vector3 = Vector3.RIGHT
var _lat_dir: Vector3 = Vector3.FORWARD
var _load: float = 0.0
var _suspension_force: Vector3 = Vector3.ZERO
var _tire_force: Vector3 = Vector3.ZERO
var _ground_torque: float = 0.0
var _last_vx: float = 0.0
var _last_vy: float = 0.0
var _last_surface_speed: float = 0.0
var _last_slip_velocity_x: float = 0.0
var _last_fx: float = 0.0
var _last_fy: float = 0.0
var _last_fx_raw: float = 0.0
var _last_fy_raw: float = 0.0
var _last_slip_ratio: float = 0.0
var _last_slip_angle: float = 0.0
var _last_lateral_slip_scale: float = 1.0
var _last_ellipse_usage: float = 0.0
var _last_ellipse_request: float = 0.0
var _last_low_speed_blend: float = 0.0
var _low_speed_active: bool = true
var _last_passive_torque: float = 0.0
var _last_tire_slip_power: float = 0.0
var _last_tire_smoke_power: float = 0.0
var _smoke_heat: float = 0.0
var _last_smoke_ratio: float = 0.0

@onready var raycast: RayCast3D = $RayCast
@onready var wheel: Wheel = $Wheel
@onready var brake: BrakeZoom = $BrakeZoom

func _ready() -> void:
	_last_length = rest_length

func configure(config: Dictionary) -> void:
	wheel_radius = config.get("wheel_radius", wheel_radius)
	wheel_inertia = config.get("wheel_inertia", wheel_inertia)
	rest_length = config.get("rest_length", rest_length)
	stiffness = config.get("stiffness", stiffness)
	damping_compression = config.get("damping_compression", damping_compression)
	damping_relaxation = config.get("damping_relaxation", damping_relaxation)
	max_suspension_force = config.get("max_suspension_force", max_suspension_force)
	mu_longitudinal = config.get("mu_longitudinal", mu_longitudinal)
	mu_lateral = config.get("mu_lateral", mu_lateral)
	slip_speed_reference = config.get("slip_speed_reference", slip_speed_reference)
	lateral_speed_reference = config.get("lateral_speed_reference", lateral_speed_reference)
	low_speed_enter = config.get("low_speed_enter", low_speed_enter)
	low_speed_exit = config.get("low_speed_exit", low_speed_exit)
	low_speed_blend_rate = config.get("low_speed_blend_rate", low_speed_blend_rate)
	low_speed_longitudinal_stiffness = config.get("low_speed_longitudinal_stiffness", low_speed_longitudinal_stiffness)
	low_speed_lateral_stiffness = config.get("low_speed_lateral_stiffness", low_speed_lateral_stiffness)
	longitudinal_slip_lateral_fade_start = config.get("longitudinal_slip_lateral_fade_start", longitudinal_slip_lateral_fade_start)
	longitudinal_slip_lateral_fade_end = config.get("longitudinal_slip_lateral_fade_end", longitudinal_slip_lateral_fade_end)
	force_rate_limit = config.get("force_rate_limit", force_rate_limit)
	force_deadband = config.get("force_deadband", force_deadband)
	rolling_resistance_coefficient = config.get("rolling_resistance_coefficient", rolling_resistance_coefficient)
	wheel_viscous_drag = config.get("wheel_viscous_drag", wheel_viscous_drag)
	wheel_constant_drag = config.get("wheel_constant_drag", wheel_constant_drag)
	smoke_longitudinal_slip_start = config.get("smoke_longitudinal_slip_start", smoke_longitudinal_slip_start)
	smoke_longitudinal_slip_full = config.get("smoke_longitudinal_slip_full", smoke_longitudinal_slip_full)
	smoke_lateral_angle_start_deg = config.get("smoke_lateral_angle_start_deg", smoke_lateral_angle_start_deg)
	smoke_lateral_angle_full_deg = config.get("smoke_lateral_angle_full_deg", smoke_lateral_angle_full_deg)
	smoke_heat_capacity = config.get("smoke_heat_capacity", smoke_heat_capacity)
	smoke_cooling_rate = config.get("smoke_cooling_rate", smoke_cooling_rate)
	smoke_visible_heat_start = config.get("smoke_visible_heat_start", smoke_visible_heat_start)
	smoke_visible_heat_full = config.get("smoke_visible_heat_full", smoke_visible_heat_full)
	brake_torque = config.get("brake_torque", brake_torque)
	static_omega_threshold = config.get("static_omega_threshold", static_omega_threshold)
	use_tire_curves = config.get("use_tire_curves", use_tire_curves)
	longitudinal_tire_curve = config.get("longitudinal_tire_curve", longitudinal_tire_curve)
	lateral_tire_curve = config.get("lateral_tire_curve", lateral_tire_curve)
	pacejka_longitudinal_b = config.get("pacejka_longitudinal_b", pacejka_longitudinal_b)
	pacejka_longitudinal_c = config.get("pacejka_longitudinal_c", pacejka_longitudinal_c)
	pacejka_longitudinal_e = config.get("pacejka_longitudinal_e", pacejka_longitudinal_e)
	pacejka_lateral_b = config.get("pacejka_lateral_b", pacejka_lateral_b)
	pacejka_lateral_c = config.get("pacejka_lateral_c", pacejka_lateral_c)
	pacejka_lateral_e = config.get("pacejka_lateral_e", pacejka_lateral_e)

	raycast.target_position = Vector3(0.0, -(rest_length + wheel_radius), 0.0)
	raycast.enabled = true
	raycast.exclude_parent = true
	wheel.set_radius(wheel_radius)
	wheel.set_mirror(mirror_wheel)
	brake.max_torque = brake_torque
	_last_length = rest_length

func set_steer_angle(angle: float) -> void:
	rotation.y = angle if is_steer else 0.0

func sample_contact(delta: float, car_linear_velocity: Vector3, car_angular_velocity: Vector3, rotation_center: Vector3) -> void:
	raycast.force_raycast_update()
	_hub_point = global_position
	_grounded = raycast.is_colliding()

	if not _grounded:
		_last_length = rest_length
		_load = 0.0
		_suspension_force = Vector3.ZERO
		_tire_force = Vector3.ZERO
		_ground_torque = 0.0
		_last_vx = 0.0
		_last_vy = 0.0
		_last_surface_speed = 0.0
		_last_slip_velocity_x = 0.0
		_last_fx_raw = 0.0
		_last_fy_raw = 0.0
		_last_slip_ratio = 0.0
		_last_slip_angle = 0.0
		_last_lateral_slip_scale = 0.0
		_last_ellipse_usage = 0.0
		_last_ellipse_request = 0.0
		_last_tire_slip_power = 0.0
		_last_tire_smoke_power = 0.0
		return

	_contact_point = raycast.get_collision_point()
	_normal = raycast.get_collision_normal().normalized()
	var current_length: float = _contact_point.distance_to(_hub_point) - wheel_radius
	current_length = clamp(current_length, 0.0, rest_length)

	var compression: float = rest_length - current_length
	compression *= clamp(_normal.dot(global_basis.y.normalized()), 0.0, 1.0)
	var length_velocity: float = (current_length - _last_length) / max(delta, 0.000001)
	var damping: float = damping_compression if length_velocity < 0.0 else damping_relaxation
	var spring_force: float = compression * stiffness
	var damper_force: float = -length_velocity * damping

	_load = clamp(spring_force + damper_force, 0.0, max_suspension_force)
	_suspension_force = _normal * _load
	_last_length = current_length

	_long_dir = _project_on_plane(global_basis.x, _normal)
	if _long_dir.length_squared() < 0.0001:
		_long_dir = _project_on_plane(Vector3.RIGHT, _normal)
	_long_dir = _long_dir.normalized()

	_lat_dir = _project_on_plane(global_basis.z, _normal)
	if _lat_dir.length_squared() < 0.0001:
		_lat_dir = _normal.cross(_long_dir)
	_lat_dir = _lat_dir.normalized()

	var contact_velocity: Vector3 = car_linear_velocity + car_angular_velocity.cross(_contact_point - rotation_center)
	contact_velocity = _project_on_plane(contact_velocity, _normal)
	_last_vx = contact_velocity.dot(_long_dir)
	_last_vy = contact_velocity.dot(_lat_dir)

func set_brake_input(value: float) -> void:
	brake.set_input(value)

func get_contact_vx_for_center(
		car_linear_velocity: Vector3,
		car_angular_velocity: Vector3,
		rotation_center: Vector3) -> float:
	return _get_contact_velocity_for_center(car_linear_velocity, car_angular_velocity, rotation_center).dot(_long_dir)

func get_contact_vy_for_center(
		car_linear_velocity: Vector3,
		car_angular_velocity: Vector3,
		rotation_center: Vector3) -> float:
	return _get_contact_velocity_for_center(car_linear_velocity, car_angular_velocity, rotation_center).dot(_lat_dir)

func get_brake_torque_guess(omega: float) -> float:
	return brake.get_torque_guess(omega, _last_vx, wheel_radius)

func get_brake_capacity() -> float:
	return brake.get_capacity()

func get_passive_torque(omega: float) -> float:
	var torque: float = 0.0
	if abs(omega) > 0.001:
		torque -= wheel_viscous_drag * omega
		torque -= wheel_constant_drag * sign(omega)

	var ref_sign: float = sign(omega)
	if ref_sign == 0.0:
		ref_sign = sign(_last_vx)
	if _grounded and ref_sign != 0.0:
		torque -= ref_sign * rolling_resistance_coefficient * _load * wheel_radius

	return torque

func predict_free_wheel_omega(delta: float) -> float:
	var passive_torque: float = get_passive_torque(_wheel_omega)
	var external_torque: float = _ground_torque + passive_torque
	var brake_torque_prediction: float = brake.predict_torque_with_lock(_wheel_omega, external_torque, static_omega_threshold)
	if brake.would_lock(_wheel_omega, external_torque, static_omega_threshold):
		return 0.0

	var predicted_omega: float = _wheel_omega + (external_torque + brake_torque_prediction) * delta / max(wheel_inertia, 0.001)
	if brake_torque_prediction != 0.0 and _wheel_omega * predicted_omega < 0.0:
		return 0.0
	return predicted_omega

func solve_tire(delta: float, omega_for_tire: float) -> void:
	if not _grounded or _load <= 0.0:
		_tire_force = Vector3.ZERO
		_ground_torque = 0.0
		_last_fx = 0.0
		_last_fy = 0.0
		_last_fx_raw = 0.0
		_last_fy_raw = 0.0
		_last_lateral_slip_scale = 0.0
		_last_ellipse_usage = 0.0
		_last_ellipse_request = 0.0
		_update_smoke(delta, 0.0, 0.0)
		return

	var surface_speed: float = omega_for_tire * wheel_radius
	var slip_velocity_x: float = surface_speed - _last_vx
	var denom: float = max(abs(_last_vx), slip_speed_reference)
	_last_surface_speed = surface_speed
	_last_slip_velocity_x = slip_velocity_x
	_last_slip_ratio = slip_velocity_x / denom
	_last_slip_angle = atan2(_last_vy, max(abs(_last_vx), lateral_speed_reference))

	var fx_pure: float = _load * mu_longitudinal * _sample_longitudinal_tire(
		_last_slip_ratio,
		pacejka_longitudinal_b,
		pacejka_longitudinal_c,
		pacejka_longitudinal_e
	)
	var fy_pure: float = -_load * mu_lateral * _sample_lateral_tire(
		_last_slip_angle,
		pacejka_lateral_b,
		pacejka_lateral_c,
		pacejka_lateral_e
	)

	var contact_speed: float = Vector2(_last_vx, _last_vy).length()
	_update_low_speed_blend(contact_speed, delta)
	var fx_low: float = low_speed_longitudinal_stiffness * slip_velocity_x
	var fy_low: float = -low_speed_lateral_stiffness * _last_vy

	var fx_raw: float = lerp(fx_low, fx_pure, _last_low_speed_blend)
	var fy_raw: float = lerp(fy_low, fy_pure, _last_low_speed_blend)
	_last_lateral_slip_scale = _get_lateral_slip_scale(abs(_last_slip_ratio))
	fy_raw *= _last_lateral_slip_scale
	_last_fx_raw = fx_raw
	_last_fy_raw = fy_raw
	_last_ellipse_request = _ellipse_usage(fx_raw, fy_raw, _load * mu_longitudinal, _load * mu_lateral)
	var limited: Vector2 = _limit_to_ellipse(fx_raw, fy_raw, _load * mu_longitudinal, _load * mu_lateral)

	var target_fx: float = _deadband(limited.x)
	var target_fy: float = _deadband(limited.y)
	_last_fx = move_toward(_last_fx, target_fx, force_rate_limit * delta)
	_last_fy = move_toward(_last_fy, target_fy, force_rate_limit * delta)

	_tire_force = _last_fx * _long_dir + _last_fy * _lat_dir
	_ground_torque = -_last_fx * wheel_radius
	_last_ellipse_usage = _ellipse_usage(_last_fx, _last_fy, _load * mu_longitudinal, _load * mu_lateral)
	var longitudinal_slip_power: float = max(_last_fx * _last_slip_velocity_x, 0.0)
	var lateral_slip_power: float = max(-_last_fy * _last_vy, 0.0)
	var longitudinal_smoke_factor: float = _smoothstep_range(
		smoke_longitudinal_slip_start,
		smoke_longitudinal_slip_full,
		abs(_last_slip_ratio)
	)
	var lateral_smoke_factor: float = _smoothstep_range(
		deg_to_rad(smoke_lateral_angle_start_deg),
		deg_to_rad(smoke_lateral_angle_full_deg),
		abs(_last_slip_angle)
	)
	var tire_slip_power: float = longitudinal_slip_power + lateral_slip_power
	var tire_smoke_power: float = longitudinal_slip_power * longitudinal_smoke_factor + lateral_slip_power * lateral_smoke_factor
	_update_smoke(delta, tire_slip_power, tire_smoke_power)

func integrate_free_wheel(delta: float) -> void:
	if is_drive:
		return
	_last_passive_torque = get_passive_torque(_wheel_omega)
	var external_torque: float = _ground_torque + _last_passive_torque
	var brake_torque_final: float = brake.solve_torque_with_lock(_wheel_omega, external_torque, static_omega_threshold)
	if brake.is_locked():
		_wheel_omega = 0.0
		return

	var old: float = _wheel_omega
	_wheel_omega += (external_torque + brake_torque_final) * delta / max(wheel_inertia, 0.001)
	if brake_torque_final != 0.0 and old * _wheel_omega < 0.0:
		_wheel_omega = 0.0

func update_visual(omega: float) -> void:
	wheel.set_omega(omega)
	wheel.set_bas(global_basis)
	wheel.set_smoke_ratio(_last_smoke_ratio if _grounded else 0.0)
	if _grounded:
		var current_length: float = _contact_point.distance_to(_hub_point) - wheel_radius
		current_length = clamp(current_length, 0.0, rest_length)
		wheel.set_pos(_hub_point - global_basis.y * current_length)
	else:
		wheel.set_pos(_hub_point - global_basis.y * rest_length)

func reset_wheel() -> void:
	_wheel_omega = 0.0
	_last_fx = 0.0
	_last_fy = 0.0
	_last_tire_slip_power = 0.0
	_last_tire_smoke_power = 0.0
	_smoke_heat = 0.0
	_last_smoke_ratio = 0.0
	_tire_force = Vector3.ZERO
	_ground_torque = 0.0
	wheel.set_smoke_ratio(0.0)

func is_grounded() -> bool:
	return _grounded

func get_hub_point() -> Vector3:
	return _hub_point

func get_contact_point() -> Vector3:
	return _contact_point

func get_suspension_force() -> Vector3:
	return _suspension_force

func get_tire_force() -> Vector3:
	return _tire_force

func get_ground_torque() -> float:
	return _ground_torque

func get_free_wheel_omega() -> float:
	return _wheel_omega

func get_wheel_inertia() -> float:
	return wheel_inertia

func get_wheel_radius() -> float:
	return wheel_radius

func get_longitudinal_grip_torque() -> float:
	return _load * mu_longitudinal * wheel_radius

func get_longitudinal_grip_force() -> float:
	return _load * mu_longitudinal

func get_lateral_grip_force() -> float:
	return _load * mu_lateral

func get_last_passive_torque() -> float:
	return _last_passive_torque

func get_last_tire_slip_power() -> float:
	return _last_tire_slip_power

func get_last_tire_smoke_power() -> float:
	return _last_tire_smoke_power

func get_smoke_heat() -> float:
	return _smoke_heat

func get_last_smoke_ratio() -> float:
	return _last_smoke_ratio

func get_load() -> float:
	return _load

func get_last_vx() -> float:
	return _last_vx

func get_last_vy() -> float:
	return _last_vy

func get_last_surface_speed() -> float:
	return _last_surface_speed

func get_last_slip_velocity_x() -> float:
	return _last_slip_velocity_x

func get_last_fx() -> float:
	return _last_fx

func get_last_fy() -> float:
	return _last_fy

func get_last_fx_raw() -> float:
	return _last_fx_raw

func get_last_fy_raw() -> float:
	return _last_fy_raw

func get_last_slip_ratio() -> float:
	return _last_slip_ratio

func get_last_slip_angle() -> float:
	return _last_slip_angle

func get_last_lateral_slip_scale() -> float:
	return _last_lateral_slip_scale

func get_last_ellipse_usage() -> float:
	return _last_ellipse_usage

func get_last_ellipse_request() -> float:
	return _last_ellipse_request

func get_last_low_speed_blend() -> float:
	return _last_low_speed_blend

func is_low_speed_active() -> bool:
	return _low_speed_active

func is_brake_locked() -> bool:
	return brake.is_locked()

func _project_on_plane(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)

func _get_contact_velocity_for_center(
		car_linear_velocity: Vector3,
		car_angular_velocity: Vector3,
		rotation_center: Vector3) -> Vector3:
	if not _grounded:
		return Vector3.ZERO
	var contact_velocity: Vector3 = car_linear_velocity + car_angular_velocity.cross(_contact_point - rotation_center)
	return _project_on_plane(contact_velocity, _normal)

func _magic_formula(x: float, b: float, c: float, e: float) -> float:
	var bx: float = b * x
	return sin(c * atan(bx - e * (bx - atan(bx))))

func _sample_longitudinal_tire(x: float, b: float, c: float, e: float) -> float:
	if use_tire_curves and longitudinal_tire_curve:
		return _sample_signed_curve(longitudinal_tire_curve, x)
	return _magic_formula(x, b, c, e)

func _sample_lateral_tire(x: float, b: float, c: float, e: float) -> float:
	if use_tire_curves and lateral_tire_curve:
		return _sample_signed_curve(lateral_tire_curve, x)
	return _magic_formula(x, b, c, e)

func _sample_signed_curve(curve: Curve, x: float) -> float:
	if curve.min_domain < 0.0:
		return curve.sample(clamp(x, curve.min_domain, curve.max_domain))

	var sample_x: float = clamp(abs(x), curve.min_domain, curve.max_domain)
	return sign(x) * curve.sample(sample_x)

func _get_lateral_slip_scale(abs_slip_ratio: float) -> float:
	var fade_start: float = max(longitudinal_slip_lateral_fade_start, 0.0)
	var fade_end: float = max(longitudinal_slip_lateral_fade_end, fade_start + 0.001)
	var t: float = clamp((abs_slip_ratio - fade_start) / (fade_end - fade_start), 0.0, 1.0)
	var smooth_t: float = t * t * (3.0 - 2.0 * t)
	return 1.0 - smooth_t

func _update_smoke(delta: float, tire_slip_power: float, tire_smoke_power: float) -> void:
	_last_tire_slip_power = tire_slip_power
	_last_tire_smoke_power = tire_smoke_power
	var heat_gain: float = tire_smoke_power * delta / max(smoke_heat_capacity, 0.001)
	var heat_loss: float = _smoke_heat * max(smoke_cooling_rate, 0.0) * delta
	_smoke_heat = max(_smoke_heat + heat_gain - heat_loss, 0.0)
	_last_smoke_ratio = _smoothstep_range(smoke_visible_heat_start, smoke_visible_heat_full, _smoke_heat)

func _smoothstep_range(edge0: float, edge1: float, value: float) -> float:
	var denom: float = max(edge1 - edge0, 0.001)
	var t: float = clamp((value - edge0) / denom, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _update_low_speed_blend(contact_speed: float, delta: float) -> void:
	if _low_speed_active:
		if contact_speed >= low_speed_exit:
			_low_speed_active = false
	else:
		if contact_speed <= low_speed_enter:
			_low_speed_active = true

	var target_blend: float = 0.0 if _low_speed_active else 1.0
	_last_low_speed_blend = move_toward(_last_low_speed_blend, target_blend, low_speed_blend_rate * delta)

func _limit_to_ellipse(fx: float, fy: float, fx_max: float, fy_max: float) -> Vector2:
	if fx_max <= 0.0 or fy_max <= 0.0:
		return Vector2.ZERO
	var usage: float = (fx / fx_max) * (fx / fx_max) + (fy / fy_max) * (fy / fy_max)
	if usage <= 1.0:
		return Vector2(fx, fy)
	var sc: float = 1.0 / sqrt(usage)
	return Vector2(fx * sc, fy * sc)

func _ellipse_usage(fx: float, fy: float, fx_max: float, fy_max: float) -> float:
	if fx_max <= 0.0 or fy_max <= 0.0:
		return 0.0
	return sqrt((fx / fx_max) * (fx / fx_max) + (fy / fy_max) * (fy / fy_max))

func _deadband(value: float) -> float:
	return 0.0 if abs(value) < force_deadband else value
