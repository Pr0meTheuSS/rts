class_name ChassisDuvet
extends Node3D

@export var steer_factor: float = 50

var suspensions: Array[SuspensionDuvet]

func _ready() -> void:
	for s in get_children():
		suspensions.append(s)

func set_steer(steer_input: float) -> void:
	for s in suspensions:
		if s.is_steer:
			s.set_steer(steer_input * steer_factor)

func get_res_forces(delta: float, drive_wheel_omega_delta: float, brake_input: float, drivetrain_inertia_moment: float) -> Dictionary[Vector3, Vector3]: #position of the wheel hub and forces on it
	var forces: Dictionary[Vector3, Vector3]
	for s in suspensions:
		forces[s.global_position] = s.get_all_forces(delta, drive_wheel_omega_delta, brake_input, drivetrain_inertia_moment)
	return forces

func get_drive_wheels_omega() -> Array[float]:
	var wheels_omega: Array[float]
	for s in suspensions:
		if s.is_drive:
			wheels_omega.append(s.get_wheel_omega())
	return wheels_omega

func get_drive_wheels_inertia_moment() -> Array[float]:
	var wheels_inertia_moment: Array[float]
	for s in suspensions:
		if s.is_drive:
			wheels_inertia_moment.append(s.wheel_inertia_moment)
	return wheels_inertia_moment

func get_drive_wheels_internal_torques() -> Array[float]:
	var wheels_internal_torques: Array[float]
	for s in suspensions:
		if s.is_drive:
			wheels_internal_torques.append(s.get_internal_torque())
	return wheels_internal_torques

func update_all_wheels_omega(delta: float, drive_wheels_omega_delta: float) -> void:
	for s in suspensions:
		s.update_wheel_omega(delta, drive_wheels_omega_delta)

func update_all_wheels_basis() -> void:
	for s in suspensions:
		s.update_wheel_basis()
