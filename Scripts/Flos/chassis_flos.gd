class_name ChassisFlos
extends Node3D

var suspensions: Array[SuspensionFlos]
var drive_wheels: Array[SuspensionFlos]
var car: CarFlos

func _ready() -> void:
	car = get_parent()
	for s in get_children() as Array[SuspensionFlos]:
		suspensions.append(s)
		s.car = car
		if s.is_drive:
			drive_wheels.append(s)

func get_drive_wheels() -> Array[SuspensionFlos]:
	return drive_wheels

func set_wheels_speed(speed: float, drifting: bool) -> void:
	for s in suspensions:
		if s.is_drive and drifting:
			s.wheel_omega = 2 * speed / s.wheel_radius
		else:
			s.wheel_omega = speed / s.wheel_radius

func set_drive_wheels_smoke_ratio(ratio: float) -> void:
	for s in get_drive_wheels():
		s.set_smoke_ratio(ratio)
