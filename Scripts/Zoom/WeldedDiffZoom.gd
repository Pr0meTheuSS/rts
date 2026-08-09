class_name WeldedDiffZoom
extends Node

@export var final_drive: float = 3.9
@export var axle_inertia: float = 0.25
@export var viscous_drag: float = 0.04
@export var constant_drag: float = 0.0
@export var static_omega_threshold: float = 0.5

var _axle_omega: float = 0.0
var _predicted_axle_omega: float = 0.0
var _predicted_brake_torque: float = 0.0
var _last_brake_torque: float = 0.0
var _last_drag_torque: float = 0.0
var _predicted_locked: bool = false
var _locked: bool = false

func get_final_drive() -> float:
	return final_drive

func get_axle_omega() -> float:
	return _axle_omega

func get_predicted_axle_omega() -> float:
	return _predicted_axle_omega

func get_predicted_brake_torque() -> float:
	return _predicted_brake_torque

func get_last_brake_torque() -> float:
	return _last_brake_torque

func get_last_drag_torque() -> float:
	return _last_drag_torque

func is_predicted_locked() -> bool:
	return _predicted_locked

func is_locked() -> bool:
	return _locked

func reset_axle() -> void:
	_axle_omega = 0.0
	_predicted_axle_omega = 0.0
	_predicted_brake_torque = 0.0
	_last_brake_torque = 0.0
	_last_drag_torque = 0.0
	_predicted_locked = false
	_locked = false

func get_total_inertia(drive_wheels_inertia: float) -> float:
	return max(axle_inertia + drive_wheels_inertia, 0.001)

func get_reflected_inertia_to_clutch(total_ratio: float, drive_wheels_inertia: float) -> float:
	return get_total_inertia(drive_wheels_inertia) / max(total_ratio * total_ratio, 0.001)

func predict_axle_omega(delta: float, drive_torque: float, brake_capacity_sum: float, inertia: float) -> float:
	_last_drag_torque = _get_drag_torque(_axle_omega)
	var external: float = drive_torque + _last_drag_torque
	_predicted_locked = _should_lock_state(_axle_omega, external, brake_capacity_sum)
	_predicted_brake_torque = _solve_brake_torque_for_state(_axle_omega, external, brake_capacity_sum)
	if _predicted_locked:
		_predicted_axle_omega = 0.0
		return _predicted_axle_omega

	var old_omega: float = _axle_omega
	var new_omega: float = old_omega + (external + _predicted_brake_torque) * delta / max(inertia, 0.001)
	if brake_capacity_sum > 0.0 and old_omega * new_omega < 0.0:
		new_omega = 0.0
	_predicted_axle_omega = new_omega
	return _predicted_axle_omega

func integrate(
		delta: float,
		drive_torque: float,
		ground_torque_sum: float,
		brake_capacity_sum: float,
		inertia: float) -> void:
	_last_drag_torque = _get_drag_torque(_axle_omega)
	var external: float = drive_torque + ground_torque_sum + _last_drag_torque
	_locked = _should_lock_state(_axle_omega, external, brake_capacity_sum)
	_last_brake_torque = _solve_brake_torque_for_state(_axle_omega, external, brake_capacity_sum)

	var old_omega: float = _axle_omega
	var new_omega: float = old_omega + (external + _last_brake_torque) * delta / max(inertia, 0.001)
	if brake_capacity_sum > 0.0 and old_omega * new_omega < 0.0:
		new_omega = 0.0
	_axle_omega = new_omega
	if _locked:
		_axle_omega = 0.0

func _get_drag_torque(omega: float) -> float:
	if abs(omega) < 0.001:
		return 0.0
	return -viscous_drag * omega - constant_drag * sign(omega)

func _should_lock_state(omega: float, external_torque: float, brake_capacity: float) -> bool:
	return brake_capacity > 0.0 and abs(omega) < static_omega_threshold and abs(external_torque) <= brake_capacity

func _solve_brake_torque_for_state(omega: float, external_torque: float, brake_capacity: float) -> float:
	if brake_capacity <= 0.0:
		return 0.0

	if _should_lock_state(omega, external_torque, brake_capacity):
		return -external_torque

	var ref_sign: float = sign(omega)
	if abs(omega) < static_omega_threshold:
		ref_sign = sign(external_torque)
	if ref_sign == 0.0:
		return 0.0
	return -ref_sign * brake_capacity
