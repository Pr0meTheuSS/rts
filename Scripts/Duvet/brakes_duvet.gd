class_name BrakesDuvet
extends Node

@export var braking_coefficient: float = 2

func get_brake_effort(brake_input: float, omega: float) -> float:
	return braking_coefficient * brake_input * wonky_brake_f(omega)

func wonky_brake_f(omega: float) -> float:
	var k1 = 7000
	var peak = 0.01
	var k2 = 0.035
	var diff = k1 * peak - k2 * peak
	if (abs(omega) < peak):
		return k1 * omega
	else:
		return -( k2 * omega + diff * sign(omega) )
