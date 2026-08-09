class_name EngineZoom
extends Node

@export var torque_curve: Curve
@export var idle_rpm: float = 950.0
@export var redline_rpm: float = 7200.0
@export var peak_torque: float = 320.0
@export var peak_torque_rpm: float = 4500.0
@export var moment_of_inertia: float = 0.22
@export var viscous_friction: float = 0.025
@export var engine_brake_torque: float = 35.0
@export var idle_torque_limit: float = 120.0
@export var idle_gain: float = 0.35

var _omega: float = 0.0
var _last_source_torque: float = 0.0

func _ready() -> void:
	_omega = Lib.rpm_to_omega(idle_rpm)

func get_omega() -> float:
	return _omega

func get_rpm() -> float:
	return Lib.omega_to_rpm(_omega)

func get_idle_rpm() -> float:
	return idle_rpm

func get_inertia() -> float:
	return moment_of_inertia

func get_last_source_torque() -> float:
	return _last_source_torque

func calculate_torque(throttle: float) -> float:
	var rpm: float = get_rpm()
	var throttle_eff: float = clamp(throttle, 0.0, 1.0)
	if rpm >= redline_rpm:
		throttle_eff = 0.0

	var combustion: float = _sample_torque(rpm) * throttle_eff
	var rpm_factor: float = clamp(rpm / max(idle_rpm, 1.0), 0.2, 1.0)
	var pumping_loss: float = engine_brake_torque * (1.0 - throttle_eff) * rpm_factor
	var friction_loss: float = viscous_friction * _omega
	var idle_torque: float = 0.0
	if rpm <= idle_rpm:
		var idle_recovery: float = clamp((idle_rpm - rpm) * idle_gain, 0.0, idle_torque_limit)
		idle_torque = min(pumping_loss + friction_loss + idle_recovery, idle_torque_limit)

	_last_source_torque = combustion + idle_torque - pumping_loss - friction_loss
	return _last_source_torque

func integrate(delta: float, net_torque: float) -> void:
	_omega += net_torque * delta / max(moment_of_inertia, 0.001)
	var min_omega: float = Lib.rpm_to_omega(idle_rpm * 0.65)
	var max_omega: float = Lib.rpm_to_omega(redline_rpm * 1.05)
	_omega = clamp(_omega, min_omega, max_omega)

func set_omega(value: float) -> void:
	_omega = clamp(value, Lib.rpm_to_omega(idle_rpm * 0.65), Lib.rpm_to_omega(redline_rpm * 1.05))

func _sample_torque(rpm: float) -> float:
	if torque_curve:
		return torque_curve.sample(clamp(rpm, torque_curve.min_domain, torque_curve.max_domain))

	return 0.0
