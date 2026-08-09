class_name TransmissionFlos
extends Node

@export var redline_speeds: Array[float]

var gears: Array[float]
var current_gear: int = 1

func gear_up() -> void:
	if current_gear < gears.size() - 1:
		current_gear += 1

func gear_down() -> void:
	if current_gear > 0:
		current_gear -= 1

func set_reverse() -> void:
	current_gear = 0

func calculate_gears(redline: float) -> void:
	for g in redline_speeds:
		gears.append(redline/Lib.kmh_to_ms(g))

func get_max_speed_ms() -> float:
	return Lib.kmh_to_ms(redline_speeds.back())

func get_omega_to_engine(linear_velocity: float, lower_gear: bool = false) -> float:
	if lower_gear and current_gear > 1:
		return linear_velocity * gears[current_gear-1]
	return linear_velocity * gears[current_gear]

func get_torque_to_body(engine_torque: float, lower_gear: bool = false) -> float:
	if lower_gear and current_gear > 1:
		return engine_torque * gears[current_gear-1]
	return engine_torque * gears[current_gear]
