class_name BrakeZoom
extends Node

@export var max_torque: float = 2400.0

var _input: float = 0.0
var _capacity: float = 0.0
var _last_torque: float = 0.0
var _locked: bool = false

func set_input(value: float) -> void:
	_input = clamp(value, 0.0, 1.0)
	_capacity = max_torque * _input

func get_capacity() -> float:
	return _capacity

func get_last_torque() -> float:
	return _last_torque

func is_locked() -> bool:
	return _locked

func get_torque_guess(omega: float, contact_vx: float, wheel_radius: float) -> float:
	_locked = false
	if _capacity <= 0.0:
		_last_torque = 0.0
		return 0.0

	var ref_sign: float = sign(omega)
	if ref_sign == 0.0:
		ref_sign = sign(contact_vx / max(wheel_radius, 0.001))
	if ref_sign == 0.0:
		_last_torque = 0.0
		return 0.0

	_last_torque = -ref_sign * _capacity
	return _last_torque

func predict_torque_with_lock(omega: float, external_torque: float, static_omega_threshold: float) -> float:
	return _solve_torque_for_state(omega, external_torque, static_omega_threshold)

func would_lock(omega: float, external_torque: float, static_omega_threshold: float) -> bool:
	return _should_lock_state(omega, external_torque, static_omega_threshold)

func solve_torque_with_lock(omega: float, external_torque: float, static_omega_threshold: float) -> float:
	_locked = _should_lock_state(omega, external_torque, static_omega_threshold)
	_last_torque = _solve_torque_for_state(omega, external_torque, static_omega_threshold)
	return _last_torque

func _should_lock_state(omega: float, external_torque: float, static_omega_threshold: float) -> bool:
	return _capacity > 0.0 and abs(omega) < static_omega_threshold and abs(external_torque) <= _capacity

func _solve_torque_for_state(omega: float, external_torque: float, static_omega_threshold: float) -> float:
	if _capacity <= 0.0:
		return 0.0

	if _should_lock_state(omega, external_torque, static_omega_threshold):
		return -external_torque

	var ref_sign: float = sign(omega)
	if abs(omega) < static_omega_threshold:
		ref_sign = sign(external_torque)
	if ref_sign == 0.0:
		return 0.0

	return -ref_sign * _capacity
