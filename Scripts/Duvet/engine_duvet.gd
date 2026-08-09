class_name EngineDuvet
extends Node

@export var stall_factor: float = 12
@export var peak_moment: float = 220
@export var peak_rpm: float = 6000
@export var peak_flatness: float = 0.9
@export var narrow_factor: float = 2500
@export var stall_rpm: float = 900
@export var redline_rpm: float = 8000

@export var flywheel_inertia: float = .2 #kg*m^2
@export var friction: float = 0.02

var _omega: float = 0

func _ready() -> void:
	_omega = rpm_to_omega(stall_rpm)

func calculate_torque(rpm: float) -> float:
	return (peak_moment - stall_factor) * \
			exp( ( - pow(( peak_flatness * ( rpm - peak_rpm ) ),2) ) / pow(narrow_factor,2) ) + \
			stall_factor

func get_rpm_on_load(delta: float, throttle: float, load_torque: float) -> float:
	var current_rpm = omega_to_rpm(_omega)
	var ecu_gas_input = throttle
	if current_rpm < (stall_rpm + 100):
		ecu_gas_input = 1
	elif current_rpm > redline_rpm:
		ecu_gas_input = 0
	var engine_torque = calculate_torque(current_rpm) * ecu_gas_input
	var friction_torque = friction * _omega
	var net_torque = engine_torque - load_torque - friction_torque
	var alpha = net_torque / flywheel_inertia  # rad/s²
	_omega += alpha * delta
	return(omega_to_rpm(_omega))

#func get_torque_at_omega(delta: float, throttle: float, clutch_omega: float) -> float:
	#var ecu_gas_input = throttle
	#var clutch_rpm = omega_to_rpm(clutch_omega)
	#if clutch_rpm < (stall_rpm + 100):
		#ecu_gas_input = 1
	#elif clutch_rpm > redline_rpm:
		#ecu_gas_input = 0
	#var engine_torque = calculate_torque(clutch_rpm) * ecu_gas_input
	#var friction_torque = friction * _omega
	#var net_torque = engine_torque - friction_torque
	##print(clutch_rpm)
	#return net_torque

func update_engine_omega(delta: float, throttle: float, sync_torque: float) -> void:
	var ecu_gas_input = throttle
	print("sync: %6.1f, rpm: %5.0f" % [sync_torque, Lib.omega_to_rpm(_omega)])
	var rpm = omega_to_rpm(_omega)
	if rpm < stall_rpm + 100:
		ecu_gas_input = 1
	elif rpm > redline_rpm:
		ecu_gas_input = 0
	var engine_torque = calculate_torque(rpm) * ecu_gas_input
	var friction_torque = friction * _omega
	var net_torque = engine_torque - friction_torque - sync_torque
	_omega += net_torque * delta / flywheel_inertia
	#var net_torque = engine_torque - friction_torque
	#print("eng: %5.1f, fri: %5.1f, syn: %5.1f" % [engine_torque, friction_torque, sync_torque])

func get_inertia_moment():
	return flywheel_inertia

func get_omega():
	return _omega

func rpm_to_omega(rpm: float) -> float:
	return rpm * PI / 30.0

func omega_to_rpm(omega: float) -> float:
	return omega * 30.0 / PI
