class_name EngineFlos
extends Node

@export var torque_curve: Curve
@export var min_rpm: int = 1000

func get_engine_redline() -> float:
	return torque_curve.max_domain

func get_power_at_omega(omega: float, throttle: float) -> float:
	if Lib.omega_to_rpm(omega) > torque_curve.max_domain: return 0
	if Lib.omega_to_rpm(omega) < min_rpm: omega = Lib.rpm_to_omega(min_rpm)
	return omega * torque_curve.sample(Lib.omega_to_rpm(omega)) * throttle

func get_torque_at_omega(omega: float, throttle: float) -> float:
	if Lib.omega_to_rpm(omega) > torque_curve.max_domain: return 0
	if Lib.omega_to_rpm(omega) < min_rpm: omega = Lib.rpm_to_omega(min_rpm)
	return torque_curve.sample(Lib.omega_to_rpm(omega)) * throttle
