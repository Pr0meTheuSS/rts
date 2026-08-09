class_name TransmissionZoom
extends Node

enum GearState { REVERSE = -2, NEUTRAL = -1, FIRST = 0 }

@export var forward_ratios: Array[float] = [3.8, 2.32, 1.62, 1.27, 1.0, 0.82]
@export var reverse_ratio: float = -3.0
@export var shift_duration: float = 0.12
@export var current_gear_state: int = GearState.FIRST

var _shift_timer: float = 0.0

func update(delta: float) -> void:
	_shift_timer = max(0.0, _shift_timer - delta)

func gear_up() -> void:
	if is_shifting():
		return
	match current_gear_state:
		GearState.REVERSE:
			current_gear_state = GearState.NEUTRAL
		GearState.NEUTRAL:
			current_gear_state = 0
		_:
			if current_gear_state < forward_ratios.size() - 1:
				current_gear_state += 1
			else:
				return
	_start_shift()

func gear_down() -> void:
	if is_shifting():
		return
	match current_gear_state:
		GearState.REVERSE:
			return
		GearState.NEUTRAL:
			current_gear_state = GearState.REVERSE
		_:
			if current_gear_state > 0:
				current_gear_state -= 1
			else:
				current_gear_state = GearState.NEUTRAL
	_start_shift()

func can_transmit_torque() -> bool:
	return not is_shifting() and current_gear_state != GearState.NEUTRAL

func is_shifting() -> bool:
	return _shift_timer > 0.0

func get_active_ratio() -> float:
	if current_gear_state == GearState.REVERSE:
		return reverse_ratio
	if current_gear_state >= 0 and current_gear_state < forward_ratios.size():
		return forward_ratios[current_gear_state]
	return 0.0

func get_gear_display() -> String:
	match current_gear_state:
		GearState.REVERSE:
			return "R"
		GearState.NEUTRAL:
			return "N"
		_:
			return str(current_gear_state + 1)

func _start_shift() -> void:
	_shift_timer = shift_duration
	GuiData.set_str_value("gear", get_gear_display())
