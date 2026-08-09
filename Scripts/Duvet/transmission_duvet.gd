class_name TransmissionDuvet
extends Node

#@export var differential: float
@export var gears: Array[float]
@export var clutch_moment: float = 200

var current_gear: int = 1

func gear_up() -> void:
	if current_gear < gears.size() - 1:
		current_gear += 1

func gear_down() -> void:
	if current_gear > 0:
		current_gear -= 1

func get_forward_torque(engine_torque: float) -> float:
	return engine_torque*gears[current_gear]

func get_backward_omega(differential_omega: float) -> float:
	return differential_omega*gears[current_gear]

func get_sync_torque(drivetrain_inertia_moment: float, engine_inertia_moment: float,
		diff_omega: float, engine_omega: float, delta: float):
	var eng_diff_inter_top = (engine_omega - diff_omega * gears[current_gear])
	var eng_dif_inter_bot = (gears[current_gear] * gears[current_gear] * engine_inertia_moment + drivetrain_inertia_moment)
	var ideal_sync_torque = \
			(drivetrain_inertia_moment * engine_inertia_moment * eng_diff_inter_top / eng_dif_inter_bot) / delta
	#print("top: %5.1f, bot: %5.1f, frac: %5.1f, dfo: %5.1f" % [eng_diff_inter_top, eng_dif_inter_bot,
			#eng_diff_inter_top/eng_dif_inter_bot, diff_omega])
	var real_sync_torque = sign(ideal_sync_torque) * min(clutch_moment, abs(ideal_sync_torque))
	return real_sync_torque
	
# Нужно посчитать моментальные моменты сил от двигателя от дороги и от тормозов и сложить их здесь
