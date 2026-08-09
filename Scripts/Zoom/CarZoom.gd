class_name CarZoom
extends RigidBody3D

enum ContactVelocityCenter { BODY_ORIGIN, CENTER_OF_MASS }

@export_file("*.json") var replay_path: String = ""
@export var contact_velocity_center: int = ContactVelocityCenter.CENTER_OF_MASS
@export var reset_lift: float = 2.5

@onready var engine: EngineZoom = $EngineZoom
@onready var clutch: ClutchZoom = $ClutchZoom
@onready var transmission: TransmissionZoom = $TransmissionZoom
@onready var welded_diff: WeldedDiffZoom = $WeldedDiffZoom
@onready var chassis: ChassisZoom = $ChassisZoom

var input_agent: InputAgent

func _ready() -> void:
	if replay_path:
		input_agent = ReplayAgent.new()
		input_agent.replay_path = replay_path
	else:
		input_agent = PlayerAgent.new()
	get_tree().root.add_child.call_deferred(input_agent)
	get_tree().root.move_child.call_deferred(input_agent, 0)
	input_agent.start()
	
	if inertia.is_zero_approx():
		inertia = Lib.calculate_aabb_inertia(self)
	
	GuiData.set_str_value("gear", transmission.get_gear_display())

func _physics_process(delta: float) -> void:
	var dt: float = max(delta, 0.000001)

	var throttle: float = _get_axis(Lib.InputType.THROTTLE, "throttle")
	var brake: float = _get_axis(Lib.InputType.BRAKE, "brake")
	var clutch_input: float = _get_axis(Lib.InputType.CLUTCH, "clutch")
	var steer: float = _get_steer()
	var gear_up: bool = _get_event(Lib.InputType.GEAR_UP, "gear up")
	var gear_down: bool = _get_event(Lib.InputType.GEAR_DOWN, "gear down")

	if _get_event(Lib.InputType.RESET, "reset") or Input.is_action_pressed("reset"):
		car_reset()
		return

	if gear_up:
		transmission.gear_up()
	if gear_down:
		transmission.gear_down()
	transmission.update(dt)

	var rotation_center: Vector3 = _get_contact_rotation_center()
	chassis.update_steer(dt, steer, linear_velocity.length())
	chassis.sample_suspensions(dt, linear_velocity, angular_velocity, rotation_center)

	var engine_torque: float = engine.calculate_torque(throttle)
	var path_open: bool = transmission.can_transmit_torque()
	var total_ratio: float = 0.0
	var clutch_torque: float = 0.0
	var axle_drive_torque: float = 0.0
	var drive_inertia: float = chassis.get_drive_wheels_inertia_sum()
	var axle_inertia: float = welded_diff.get_total_inertia(drive_inertia)

	if path_open:
		total_ratio = transmission.get_active_ratio() * welded_diff.get_final_drive()
		path_open = not is_zero_approx(total_ratio)

	clutch.update_engagement(
		dt,
		clutch_input,
		transmission.is_shifting(),
		engine.get_rpm(),
		engine.get_idle_rpm(),
		path_open
	)

	if path_open:
		var driven_omega_at_clutch: float = welded_diff.get_axle_omega() * total_ratio
		var reflected_inertia: float = welded_diff.get_reflected_inertia_to_clutch(total_ratio, drive_inertia)
		clutch_torque = clutch.calculate_torque(
			dt,
			engine.get_omega(),
			driven_omega_at_clutch,
			engine.get_inertia(),
			reflected_inertia
		)
		axle_drive_torque = clutch_torque * total_ratio

	chassis.update_brakes(brake)
	var drive_brake_capacity: float = chassis.get_drive_brake_capacity_sum()
	var drive_passive_torque: float = chassis.get_drive_passive_torque_sum(welded_diff.get_axle_omega())
	var predicted_axle_omega: float = welded_diff.predict_axle_omega(
		dt,
		axle_drive_torque + drive_passive_torque,
		drive_brake_capacity,
		axle_inertia
	)

	chassis.solve_tires(dt, predicted_axle_omega)
	var drive_ground_torque: float = chassis.get_drive_ground_torque_sum()
	welded_diff.integrate(
		dt,
		axle_drive_torque + drive_passive_torque,
		drive_ground_torque,
		drive_brake_capacity,
		axle_inertia
	)
	chassis.integrate_free_wheels(dt)

	engine.integrate(dt, engine_torque - clutch_torque)

	var force_suspensions: Array[SuspensionZoom] = chassis.get_all_suspensions()
	var force_index: int = 0
	while force_index < force_suspensions.size():
		var suspension: SuspensionZoom = force_suspensions[force_index]
		if suspension.is_grounded():
			apply_force(suspension.get_suspension_force(), suspension.get_hub_point() - global_position)
			apply_force(suspension.get_tire_force(), suspension.get_contact_point() - global_position)
		force_index += 1

	chassis.update_visuals(welded_diff.get_axle_omega())
	_publish_debug(
		throttle,
		brake,
		clutch_input,
		steer,
		total_ratio,
		path_open,
		axle_drive_torque,
		welded_diff.get_predicted_brake_torque(),
		predicted_axle_omega,
		drive_ground_torque,
		drive_passive_torque,
		drive_brake_capacity
	)

func car_reset() -> void:
	global_position += Vector3.UP * reset_lift
	rotation.x = 0.0
	rotation.z = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	welded_diff.reset_axle()
	chassis.reset_wheels()

func _get_contact_rotation_center() -> Vector3:
	if contact_velocity_center == ContactVelocityCenter.BODY_ORIGIN:
		return global_position
	return to_global(center_of_mass)

func _get_axis(type: int, action_name: String) -> float:
	var agent_value: float = input_agent.get_strength(type) if input_agent else 0.0
	return max(agent_value, Input.get_action_strength(action_name))

func _get_event(type: int, action_name: String) -> bool:
	var agent_value: float = input_agent.get_strength(type) if input_agent else 0.0
	return agent_value > 0.0 or Input.is_action_just_pressed(action_name)

func _get_steer() -> float:
	var agent_value: float = input_agent.get_strength(Lib.InputType.STEER) if input_agent else 0.0
	var direct_value: float = Input.get_axis("steer_left", "steer_right")
	return -clamp(agent_value if abs(agent_value) > abs(direct_value) else direct_value, -1.0, 1.0)

func _publish_debug(
		throttle: float,
		brake: float,
		clutch_input: float,
		steer: float,
		total_ratio: float,
		path_open: bool,
		axle_drive_torque: float,
		predicted_brake_torque: float,
		predicted_axle_omega: float,
		drive_ground_torque: float,
		drive_passive_torque: float,
		drive_brake_capacity: float) -> void:
	GuiData.set_value("zoom_throttle", throttle)
	GuiData.set_value("zoom_brake", brake)
	GuiData.set_value("zoom_clutch_input", clutch_input)
	GuiData.set_value("zoom_steer", steer)
	GuiData.set_value("zoom_steer_angle", rad_to_deg(chassis.get_actual_steer_angle()))
	GuiData.set_value("zoom_speed", Lib.ms_to_kmh(linear_velocity.dot(global_basis.x)))
	GuiData.set_value("zoom_engine_rpm", engine.get_rpm())
	GuiData.set_value("zoom_engine_torque", engine.get_last_source_torque())
	GuiData.set_value("zoom_clutch_engagement", clutch.get_engagement())
	GuiData.set_value("zoom_clutch_capacity", clutch.get_capacity())
	GuiData.set_value("zoom_clutch_torque", clutch.get_last_torque())
	GuiData.set_value("zoom_axle_omega", welded_diff.get_axle_omega())
	GuiData.set_value("zoom_predicted_axle_omega", predicted_axle_omega)
	GuiData.set_value("zoom_axle_drive_torque", axle_drive_torque)
	GuiData.set_value("zoom_drive_ground_torque", drive_ground_torque)
	GuiData.set_value("zoom_drive_passive_torque", drive_passive_torque)
	var drive_grip_torque: float = chassis.get_drive_longitudinal_grip_torque_sum()
	GuiData.set_value("zoom_drive_grip_torque", drive_grip_torque)
	GuiData.set_value("zoom_drive_torque_ratio", abs(axle_drive_torque) / max(drive_grip_torque, 0.001))
	GuiData.set_value("zoom_clutch_capacity_at_axle", clutch.get_capacity() * abs(total_ratio) if path_open else 0.0)
	GuiData.set_value("zoom_engine_omega", engine.get_omega())
	GuiData.set_value("zoom_driven_omega_at_clutch", welded_diff.get_axle_omega() * total_ratio if path_open else 0.0)
	GuiData.set_value("zoom_predicted_brake_torque", predicted_brake_torque)
	GuiData.set_value("zoom_axle_brake_torque", welded_diff.get_last_brake_torque())
	GuiData.set_value("zoom_drive_brake_guess", predicted_brake_torque)
	GuiData.set_value("zoom_drive_brake_capacity", drive_brake_capacity)
	GuiData.set_value("zoom_axle_drag_torque", welded_diff.get_last_drag_torque())
	GuiData.set_value("zoom_total_ratio", total_ratio)
	GuiData.set_value("zoom_path_open", 1.0 if path_open else 0.0)
	GuiData.set_value("zoom_axle_predicted_locked", 1.0 if welded_diff.is_predicted_locked() else 0.0)
	GuiData.set_value("zoom_axle_locked", 1.0 if welded_diff.is_locked() else 0.0)
	GuiData.set_value("zoom_drive_wheels", float(chassis.get_drive_suspensions().size()))
	GuiData.set_value("zoom_steer_wheels", float(chassis.get_steer_suspensions().size()))
	var rotation_center_mode: String = "BODY" if contact_velocity_center == ContactVelocityCenter.BODY_ORIGIN else "COM"
	var body_rotation_center: Vector3 = global_position
	var com_rotation_center: Vector3 = to_global(center_of_mass)
	GuiData.set_str_value("zoom_rotation_center", rotation_center_mode)
	GuiData.set_value("zoom_rotation_center_is_com", 1.0 if contact_velocity_center == ContactVelocityCenter.CENTER_OF_MASS else 0.0)
	GuiData.set_value("zoom_com_offset_x", center_of_mass.x)
	GuiData.set_value("zoom_com_offset_y", center_of_mass.y)
	GuiData.set_value("zoom_com_offset_z", center_of_mass.z)
	GuiData.set_value("zoom_angular_x", angular_velocity.x)
	GuiData.set_value("zoom_angular_y", angular_velocity.y)
	GuiData.set_value("zoom_angular_z", angular_velocity.z)
	GuiData.set_str_value("zoom_gear", transmission.get_gear_display())
	GuiData.set_str_value("gear", transmission.get_gear_display())
	GuiData.set_value("engine_rpm", engine.get_rpm())
	GuiData.set_value("speed", Lib.ms_to_kmh(linear_velocity.dot(global_basis.x)))

	var suspensions: Array[SuspensionZoom] = chassis.get_all_suspensions()
	var rear_count: int = 0
	var rear_slip_sum: float = 0.0
	var rear_abs_slip_max: float = 0.0
	var rear_slip_velocity_sum: float = 0.0
	var rear_long_usage_sum: float = 0.0
	var rear_lat_usage_sum: float = 0.0
	var rear_ellipse_sum: float = 0.0
	var rear_ellipse_request_sum: float = 0.0
	var rear_lateral_slip_scale_sum: float = 0.0
	var rear_smoke_sum: float = 0.0
	var rear_tire_slip_power_sum: float = 0.0
	var rear_tire_smoke_power_sum: float = 0.0
	var rear_smoke_heat_sum: float = 0.0
	var i: int = 0
	while i < suspensions.size():
		var suspension: SuspensionZoom = suspensions[i]
		var prefix: String = "zoom_w%d_" % i
		var wheel_omega: float = welded_diff.get_axle_omega() if suspension.is_drive else suspension.get_free_wheel_omega()
		var longitudinal_grip_force: float = suspension.get_longitudinal_grip_force()
		var lateral_grip_force: float = suspension.get_lateral_grip_force()
		var fx_norm: float = suspension.get_last_fx() / max(longitudinal_grip_force, 0.001)
		var fy_norm: float = suspension.get_last_fy() / max(lateral_grip_force, 0.001)
		var fx_request_norm: float = suspension.get_last_fx_raw() / max(longitudinal_grip_force, 0.001)
		var fy_request_norm: float = suspension.get_last_fy_raw() / max(lateral_grip_force, 0.001)
		var vx_body: float = suspension.get_contact_vx_for_center(linear_velocity, angular_velocity, body_rotation_center)
		var vy_body: float = suspension.get_contact_vy_for_center(linear_velocity, angular_velocity, body_rotation_center)
		var vx_com: float = suspension.get_contact_vx_for_center(linear_velocity, angular_velocity, com_rotation_center)
		var vy_com: float = suspension.get_contact_vy_for_center(linear_velocity, angular_velocity, com_rotation_center)
		GuiData.set_value(prefix + "grounded", 1.0 if suspension.is_grounded() else 0.0)
		GuiData.set_value(prefix + "omega", wheel_omega)
		GuiData.set_value(prefix + "fz", suspension.get_load())
		GuiData.set_value(prefix + "fx", suspension.get_last_fx())
		GuiData.set_value(prefix + "fy", suspension.get_last_fy())
		GuiData.set_value(prefix + "fx_raw", suspension.get_last_fx_raw())
		GuiData.set_value(prefix + "fy_raw", suspension.get_last_fy_raw())
		GuiData.set_value(prefix + "fx_limit", longitudinal_grip_force)
		GuiData.set_value(prefix + "fy_limit", lateral_grip_force)
		GuiData.set_value(prefix + "fx_norm", fx_norm)
		GuiData.set_value(prefix + "fy_norm", fy_norm)
		GuiData.set_value(prefix + "fx_request_norm", fx_request_norm)
		GuiData.set_value(prefix + "fy_request_norm", fy_request_norm)
		GuiData.set_value(prefix + "passive_torque", suspension.get_passive_torque(wheel_omega))
		GuiData.set_value(prefix + "ground_torque", suspension.get_ground_torque())
		GuiData.set_value(prefix + "vx", suspension.get_last_vx())
		GuiData.set_value(prefix + "vy", suspension.get_last_vy())
		GuiData.set_value(prefix + "surface_speed", suspension.get_last_surface_speed())
		GuiData.set_value(prefix + "slip_velocity_x", suspension.get_last_slip_velocity_x())
		GuiData.set_value(prefix + "vx_body", vx_body)
		GuiData.set_value(prefix + "vy_body", vy_body)
		GuiData.set_value(prefix + "vx_com", vx_com)
		GuiData.set_value(prefix + "vy_com", vy_com)
		GuiData.set_value(prefix + "vx_center_delta", vx_com - vx_body)
		GuiData.set_value(prefix + "vy_center_delta", vy_com - vy_body)
		GuiData.set_value(prefix + "slip", suspension.get_last_slip_ratio())
		GuiData.set_value(prefix + "angle", rad_to_deg(suspension.get_last_slip_angle()))
		GuiData.set_value(prefix + "lateral_slip_scale", suspension.get_last_lateral_slip_scale())
		GuiData.set_value(prefix + "ellipse", suspension.get_last_ellipse_usage())
		GuiData.set_value(prefix + "ellipse_request", suspension.get_last_ellipse_request())
		GuiData.set_value(prefix + "low_speed", suspension.get_last_low_speed_blend())
		GuiData.set_value(prefix + "low_speed_active", 1.0 if suspension.is_low_speed_active() else 0.0)
		GuiData.set_value(prefix + "brake_locked", 1.0 if suspension.is_brake_locked() else 0.0)
		GuiData.set_value(prefix + "tire_slip_power", suspension.get_last_tire_slip_power())
		GuiData.set_value(prefix + "tire_smoke_power", suspension.get_last_tire_smoke_power())
		GuiData.set_value(prefix + "smoke_heat", suspension.get_smoke_heat())
		GuiData.set_value(prefix + "smoke_ratio", suspension.get_last_smoke_ratio())
		if suspension.is_drive:
			rear_count += 1
			rear_slip_sum += suspension.get_last_slip_ratio()
			rear_abs_slip_max = max(rear_abs_slip_max, abs(suspension.get_last_slip_ratio()))
			rear_slip_velocity_sum += suspension.get_last_slip_velocity_x()
			rear_long_usage_sum += abs(fx_norm)
			rear_lat_usage_sum += abs(fy_norm)
			rear_ellipse_sum += suspension.get_last_ellipse_usage()
			rear_ellipse_request_sum += suspension.get_last_ellipse_request()
			rear_lateral_slip_scale_sum += suspension.get_last_lateral_slip_scale()
			rear_smoke_sum += suspension.get_last_smoke_ratio()
			rear_tire_slip_power_sum += suspension.get_last_tire_slip_power()
			rear_tire_smoke_power_sum += suspension.get_last_tire_smoke_power()
			rear_smoke_heat_sum += suspension.get_smoke_heat()
		i += 1

	var rear_divisor: float = max(float(rear_count), 1.0)
	GuiData.set_value("zoom_rear_slip_avg", rear_slip_sum / rear_divisor)
	GuiData.set_value("zoom_rear_slip_abs_max", rear_abs_slip_max)
	GuiData.set_value("zoom_rear_slip_velocity_avg", rear_slip_velocity_sum / rear_divisor)
	GuiData.set_value("zoom_rear_long_usage", rear_long_usage_sum / rear_divisor)
	GuiData.set_value("zoom_rear_lat_usage", rear_lat_usage_sum / rear_divisor)
	GuiData.set_value("zoom_rear_ellipse", rear_ellipse_sum / rear_divisor)
	GuiData.set_value("zoom_rear_ellipse_request", rear_ellipse_request_sum / rear_divisor)
	GuiData.set_value("zoom_rear_lateral_slip_scale", rear_lateral_slip_scale_sum / rear_divisor)
	GuiData.set_value("zoom_rear_smoke_ratio", rear_smoke_sum / rear_divisor)
	GuiData.set_value("zoom_rear_tire_slip_power", rear_tire_slip_power_sum / rear_divisor)
	GuiData.set_value("zoom_rear_tire_smoke_power", rear_tire_smoke_power_sum / rear_divisor)
	GuiData.set_value("zoom_rear_smoke_heat", rear_smoke_heat_sum / rear_divisor)
