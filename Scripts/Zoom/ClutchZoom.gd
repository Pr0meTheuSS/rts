class_name ClutchZoom
extends Node

@export var max_torque: float = 520.0
@export var engage_rate: float = 8.0
@export var disengage_rate: float = 30.0
@export var idle_resume_margin_rpm: float = 250.0

var _engagement: float = 0.0
var _last_torque: float = 0.0

func update_engagement(
		delta: float,
		clutch_input: float,
		shifting: bool,
		engine_rpm: float,
		idle_rpm: float,
		path_open: bool) -> void:
	var target: float = 1.0 - clamp(clutch_input, 0.0, 1.0)
	if shifting or not path_open:
		target = 0.0
	elif engine_rpm < idle_rpm:
		var idle_recovery_start: float = idle_rpm - idle_resume_margin_rpm
		var idle_protection_limit: float = clamp(
			(engine_rpm - idle_recovery_start) / max(idle_resume_margin_rpm, 1.0),
			0.0,
			1.0
		)
		target = min(target, idle_protection_limit)

	var rate: float = engage_rate if target > _engagement else disengage_rate
	_engagement = move_toward(_engagement, target, rate * delta)

func calculate_torque(
		delta: float,
		engine_omega: float,
		driven_omega: float,
		engine_inertia: float,
		driven_inertia: float) -> float:
	var capacity: float = get_capacity()
	if capacity <= 0.0 or driven_inertia <= 0.0:
		_last_torque = 0.0
		return 0.0

	var omega_error: float = engine_omega - driven_omega
	if abs(omega_error) < 0.001:
		_last_torque = 0.0
		return 0.0

	var denom: float = 1.0 / max(engine_inertia, 0.001) + 1.0 / max(driven_inertia, 0.001)
	var ideal_impulse: float = omega_error / denom
	var ideal_torque: float = ideal_impulse / max(delta, 0.000001)
	_last_torque = clamp(ideal_torque, -capacity, capacity)
	return _last_torque

func get_capacity() -> float:
	return max_torque * _engagement

func get_engagement() -> float:
	return _engagement

func get_last_torque() -> float:
	return _last_torque
