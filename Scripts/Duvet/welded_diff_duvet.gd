class_name WeldedDiffDuvet
extends Node

@export var ratio: float = 3.42
@export var inertia_moment: float = 0.2

func get_one_wheel_torque(transmission_torque: float) -> float:
	return transmission_torque*ratio/2

func get_omega(wheels_omega: Array[float]) -> float:
	var sum = 0
	for omega in wheels_omega:
		sum += omega
	#print("w1: %5.1f, w2: %5.1f, sum: %5.1f" % [wheels_omega[0], wheels_omega[1], sum])
	return sum/wheels_omega.size()*ratio

func get_net_torque(sync_torque: float, wheels_internal_torques: Array[float]) -> float:
	var total_wheels_internal_torque = 0
	for torque in wheels_internal_torques:
		total_wheels_internal_torque += torque
	total_wheels_internal_torque /= ratio
	var net_torque = sync_torque + total_wheels_internal_torque
	return net_torque

func get_drive_wheel_omega_delta(delta: float, sync_torque: float,
		wheels_internal_torques: Array[float], drivetrain_inertia_moment: float) -> float:
	var drive_wheel_omega_delta : float = 0
	var net_torque = get_net_torque(sync_torque, wheels_internal_torques)
	drive_wheel_omega_delta = net_torque * delta / drivetrain_inertia_moment / ratio
	return drive_wheel_omega_delta
