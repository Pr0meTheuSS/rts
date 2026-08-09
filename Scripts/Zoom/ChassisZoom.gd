class_name ChassisZoom
extends Node3D

@export_group("Wheel Common")
@export var wheel_radius: float = 0.335
@export var wheel_inertia: float = 9.0
@export var rest_length: float = 0.18
@export var stiffness: float = 62000.0
@export var damping_compression: float = 4300.0
@export var damping_relaxation: float = 4700.0
@export var max_suspension_force: float = 18000.0
@export var static_omega_threshold: float = 0.5

@export_group("Tires")
@export var mu_longitudinal: float = 1.35
@export var mu_lateral: float = 1.35
@export var slip_speed_reference: float = 1.0
@export var lateral_speed_reference: float = 1.0
@export var low_speed_enter: float = 0.45
@export var low_speed_exit: float = 1.5
@export var low_speed_blend_rate: float = 8.0
@export var low_speed_longitudinal_stiffness: float = 9000.0
@export var low_speed_lateral_stiffness: float = 11000.0
@export var longitudinal_slip_lateral_fade_start: float = 0.2
@export var longitudinal_slip_lateral_fade_end: float = 1.2
@export var force_rate_limit: float = 320000.0
@export var force_deadband: float = 4.0
@export var rolling_resistance_coefficient: float = 0.015
@export var wheel_viscous_drag: float = 0.02
@export var wheel_constant_drag: float = 0.0
@export var smoke_longitudinal_slip_start: float = 0.35
@export var smoke_longitudinal_slip_full: float = 1.8
@export var smoke_lateral_angle_start_deg: float = 15.0
@export var smoke_lateral_angle_full_deg: float = 35.0
@export var smoke_heat_capacity: float = 60000.0
@export var smoke_cooling_rate: float = 1.2
@export var smoke_visible_heat_start: float = 0.25
@export var smoke_visible_heat_full: float = 1.0
@export var use_tire_curves: bool = false
@export var longitudinal_tire_curve: Curve
@export var lateral_tire_curve: Curve
@export var pacejka_longitudinal_b: float = 10.0
@export var pacejka_longitudinal_c: float = 1.65
@export var pacejka_longitudinal_e: float = 0.97
@export var pacejka_lateral_b: float = 7.5
@export var pacejka_lateral_c: float = 1.35
@export var pacejka_lateral_e: float = 0.8

@export_group("Brakes")
@export var front_brake_torque: float = 2600.0
@export var rear_brake_torque: float = 2400.0

@export_group("Steering")
@export var max_steer_angle_deg: float = 38.0
@export var steer_speed: float = 7.0
@export var steer_return_speed: float = 11.0

var all_suspensions: Array[SuspensionZoom] = []
var steer_suspensions: Array[SuspensionZoom] = []
var drive_suspensions: Array[SuspensionZoom] = []

var _actual_steer_angle: float = 0.0

func _ready() -> void:
	_collect_suspensions()
	_configure_suspensions()

func update_steer(delta: float, steer_input: float, _car_speed: float) -> void:
	var max_angle: float = deg_to_rad(max_steer_angle_deg)
	var target: float = max_angle * clamp(steer_input, -1.0, 1.0)
	var rate: float = steer_speed if abs(target) > abs(_actual_steer_angle) else steer_return_speed
	_actual_steer_angle = move_toward(_actual_steer_angle, target, rate * delta)
	var suspension_index: int = 0
	while suspension_index < steer_suspensions.size():
		var suspension: SuspensionZoom = steer_suspensions[suspension_index]
		suspension.set_steer_angle(_actual_steer_angle)
		suspension_index += 1

func sample_suspensions(
		delta: float,
		car_linear_velocity: Vector3,
		car_angular_velocity: Vector3,
		rotation_center: Vector3) -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		suspension.sample_contact(delta, car_linear_velocity, car_angular_velocity, rotation_center)
		suspension_index += 1

func update_brakes(brake_input: float) -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		suspension.set_brake_input(brake_input)
		suspension_index += 1

func get_drive_brake_torque_guess_sum(axle_omega: float) -> float:
	var sum: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		sum += suspension.get_brake_torque_guess(axle_omega)
		suspension_index += 1
	return sum

func solve_tires(delta: float, drive_axle_omega: float) -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		var omega_for_tire: float = drive_axle_omega if suspension.is_drive else suspension.predict_free_wheel_omega(delta)
		suspension.solve_tire(delta, omega_for_tire)
		suspension_index += 1

func integrate_free_wheels(delta: float) -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		if not suspension.is_drive:
			suspension.integrate_free_wheel(delta)
		suspension_index += 1

func update_visuals(drive_axle_omega: float) -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		var omega: float = drive_axle_omega if suspension.is_drive else suspension.get_free_wheel_omega()
		suspension.update_visual(omega)
		suspension_index += 1

func reset_wheels() -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		suspension.reset_wheel()
		suspension_index += 1

func get_all_suspensions() -> Array[SuspensionZoom]:
	return all_suspensions

func get_drive_suspensions() -> Array[SuspensionZoom]:
	return drive_suspensions

func get_steer_suspensions() -> Array[SuspensionZoom]:
	return steer_suspensions

func get_drive_wheels_inertia_sum() -> float:
	var total: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		total += suspension.get_wheel_inertia()
		suspension_index += 1
	return total

func get_drive_ground_torque_sum() -> float:
	var total: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		total += suspension.get_ground_torque()
		suspension_index += 1
	return total

func get_drive_passive_torque_sum(axle_omega: float) -> float:
	var total: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		total += suspension.get_passive_torque(axle_omega)
		suspension_index += 1
	return total

func get_drive_longitudinal_grip_torque_sum() -> float:
	var total: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		total += suspension.get_longitudinal_grip_torque()
		suspension_index += 1
	return total

func get_drive_brake_capacity_sum() -> float:
	var total: float = 0.0
	var suspension_index: int = 0
	while suspension_index < drive_suspensions.size():
		var suspension: SuspensionZoom = drive_suspensions[suspension_index]
		total += suspension.get_brake_capacity()
		suspension_index += 1
	return total

func get_actual_steer_angle() -> float:
	return _actual_steer_angle

func _collect_suspensions() -> void:
	all_suspensions.clear()
	steer_suspensions.clear()
	drive_suspensions.clear()

	var children: Array[Node] = get_children()
	var child_index: int = 0
	while child_index < children.size():
		var child: Node = children[child_index]
		if child is SuspensionZoom:
			var suspension: SuspensionZoom = child as SuspensionZoom
			all_suspensions.append(suspension)
			if suspension.is_steer:
				steer_suspensions.append(suspension)
			if suspension.is_drive:
				drive_suspensions.append(suspension)
		child_index += 1

func _configure_suspensions() -> void:
	var suspension_index: int = 0
	while suspension_index < all_suspensions.size():
		var suspension: SuspensionZoom = all_suspensions[suspension_index]
		var brake_torque: float = rear_brake_torque if suspension.is_drive else front_brake_torque
		suspension.configure({
			"wheel_radius": wheel_radius,
			"wheel_inertia": wheel_inertia,
			"rest_length": rest_length,
			"stiffness": stiffness,
			"damping_compression": damping_compression,
			"damping_relaxation": damping_relaxation,
			"max_suspension_force": max_suspension_force,
			"mu_longitudinal": mu_longitudinal,
			"mu_lateral": mu_lateral,
			"slip_speed_reference": slip_speed_reference,
			"lateral_speed_reference": lateral_speed_reference,
			"low_speed_enter": low_speed_enter,
			"low_speed_exit": low_speed_exit,
			"low_speed_blend_rate": low_speed_blend_rate,
			"low_speed_longitudinal_stiffness": low_speed_longitudinal_stiffness,
			"low_speed_lateral_stiffness": low_speed_lateral_stiffness,
			"longitudinal_slip_lateral_fade_start": longitudinal_slip_lateral_fade_start,
			"longitudinal_slip_lateral_fade_end": longitudinal_slip_lateral_fade_end,
			"force_rate_limit": force_rate_limit,
			"force_deadband": force_deadband,
			"rolling_resistance_coefficient": rolling_resistance_coefficient,
			"wheel_viscous_drag": wheel_viscous_drag,
			"wheel_constant_drag": wheel_constant_drag,
			"smoke_longitudinal_slip_start": smoke_longitudinal_slip_start,
			"smoke_longitudinal_slip_full": smoke_longitudinal_slip_full,
			"smoke_lateral_angle_start_deg": smoke_lateral_angle_start_deg,
			"smoke_lateral_angle_full_deg": smoke_lateral_angle_full_deg,
			"smoke_heat_capacity": smoke_heat_capacity,
			"smoke_cooling_rate": smoke_cooling_rate,
			"smoke_visible_heat_start": smoke_visible_heat_start,
			"smoke_visible_heat_full": smoke_visible_heat_full,
			"use_tire_curves": use_tire_curves,
			"longitudinal_tire_curve": longitudinal_tire_curve,
			"lateral_tire_curve": lateral_tire_curve,
			"pacejka_longitudinal_b": pacejka_longitudinal_b,
			"pacejka_longitudinal_c": pacejka_longitudinal_c,
			"pacejka_longitudinal_e": pacejka_longitudinal_e,
			"pacejka_lateral_b": pacejka_lateral_b,
			"pacejka_lateral_c": pacejka_lateral_c,
			"pacejka_lateral_e": pacejka_lateral_e,
			"brake_torque": brake_torque,
			"static_omega_threshold": static_omega_threshold,
		})
		suspension_index += 1
