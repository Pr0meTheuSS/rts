extends Control

@onready var label: Label = $MarginContainer/HBoxContainer/Label
@onready var inputs_monitor: Particle1DMonitor = $MonitorInputs
@onready var drive_monitor: Particle1DMonitor = $MonitorDrive
@onready var rear_force_monitor: Particle1DMonitor = $MonitorRearForces
@onready var rear_slip_monitor: Particle1DMonitor = $MonitorRearSlip
@onready var rotation_vx_monitor: Particle1DMonitor = $MonitorRotationVx
@onready var rotation_vy_monitor: Particle1DMonitor = $MonitorRotationVy

func _ready() -> void:
	inputs_monitor.configure(_monitor_config(
		"inputs",
		-1.05,
		1.05,
		[
			_series("zoom_throttle", Color.LIME_GREEN, 2.0),
			_series("zoom_brake", Color.CRIMSON, 2.0),
			_series("zoom_clutch_input", Color.DEEP_SKY_BLUE, 2.0),
			_series("zoom_steer", Color.GOLD, 2.0),
		],
		{-1.0: "-1", 0.0: "0", 1.0: "1"}
	))
	drive_monitor.configure(_monitor_config(
		"drive torque",
		-18000.0,
		18000.0,
		[
			_series("zoom_axle_drive_torque", Color.ORANGE, 3.0),
			_series("zoom_clutch_capacity_at_axle", Color.YELLOW, 2.5),
			_series("zoom_drive_grip_torque", Color.LIME_GREEN, 2.5),
			_series("zoom_drive_ground_torque", Color.CYAN, 2.0),
			_series("zoom_drive_passive_torque", Color.MEDIUM_PURPLE, 1.8),
		],
		{-15000.0: "-15k", 0.0: "0", 15000.0: "15k"}
	))
	rear_force_monitor.configure(_monitor_config(
		"rear grip usage",
		0.0,
		2.2,
		[
			_series("zoom_rear_long_usage", Color.ORANGE, 3.0),
			_series("zoom_rear_lat_usage", Color.DEEP_SKY_BLUE, 2.5),
			_series("zoom_rear_lateral_slip_scale", Color.HOT_PINK, 2.5),
			_series("zoom_rear_smoke_ratio", Color.WHITE, 2.0),
			_series("zoom_rear_ellipse_request", Color.CRIMSON, 2.5),
			_series("zoom_rear_ellipse", Color.LIME_GREEN, 2.5),
		],
		{0.0: "0", 1.0: "1", 2.0: "2"}
	))
	rear_slip_monitor.configure(_monitor_config(
		"rear slip ratio",
		-8.0,
		8.0,
		[
			_series("zoom_w2_slip", Color.ORANGE, 2.5),
			_series("zoom_w3_slip", Color.GOLD, 2.0),
			_series("zoom_rear_slip_abs_max", Color.WHITE, 2.0),
			_series("zoom_drive_torque_ratio", Color.CRIMSON, 2.5),
		],
		{-4.0: "-4", -1.0: "-1", 0.0: "0", 1.0: "1", 4.0: "4"}
	))
	rotation_vx_monitor.configure(_monitor_config(
		"center delta Vx",
		-0.5,
		0.5,
		[
			_series("zoom_w0_vx_center_delta", Color.HOT_PINK, 2.0),
			_series("zoom_w1_vx_center_delta", Color.DEEP_SKY_BLUE, 2.0),
			_series("zoom_w2_vx_center_delta", Color.ORANGE, 2.0),
			_series("zoom_w3_vx_center_delta", Color.GOLD, 2.0),
		],
		{-0.5: "-.5", 0.0: "0", 0.5: ".5"}
	))
	rotation_vy_monitor.configure(_monitor_config(
		"center delta Vy",
		-0.5,
		0.5,
		[
			_series("zoom_w0_vy_center_delta", Color.HOT_PINK, 2.0),
			_series("zoom_w1_vy_center_delta", Color.DEEP_SKY_BLUE, 2.0),
			_series("zoom_w2_vy_center_delta", Color.ORANGE, 2.0),
			_series("zoom_w3_vy_center_delta", Color.GOLD, 2.0),
		],
		{-0.5: "-.5", 0.0: "0", 0.5: ".5"}
	))

func _process(_delta: float) -> void:
	var gear: String = GuiData.get_str_value("zoom_gear", "N")
	var rpm: float = GuiData.get_value("zoom_engine_rpm", 0.0)
	var speed: float = GuiData.get_value("zoom_speed", 0.0)
	var throttle: float = GuiData.get_value("zoom_throttle", 0.0)
	var brake: float = GuiData.get_value("zoom_brake", 0.0)
	var clutch: float = GuiData.get_value("zoom_clutch_engagement", 0.0)
	var steer: float = GuiData.get_value("zoom_steer", 0.0)
	var steer_angle: float = GuiData.get_value("zoom_steer_angle", 0.0)
	var drive_wheels: int = int(GuiData.get_value("zoom_drive_wheels", 0.0))
	var steer_wheels: int = int(GuiData.get_value("zoom_steer_wheels", 0.0))
	var path_open: int = int(GuiData.get_value("zoom_path_open", 0.0))
	var rotation_center: String = GuiData.get_str_value("zoom_rotation_center", "?")
	var com_x: float = GuiData.get_value("zoom_com_offset_x", 0.0)
	var com_y: float = GuiData.get_value("zoom_com_offset_y", 0.0)
	var com_z: float = GuiData.get_value("zoom_com_offset_z", 0.0)
	var yaw_rate: float = GuiData.get_value("zoom_angular_y", 0.0)
	var predicted_locked: int = int(GuiData.get_value("zoom_axle_predicted_locked", 0.0))
	var axle_locked: int = int(GuiData.get_value("zoom_axle_locked", 0.0))
	label.text = "G:%s RPM:%5.0f V:%5.1f T:%2.0f B:%2.0f C:%2.0f S:%+.2f/%+.0f W:%d/%d P:%d RC:%s CM:%+.2f/%+.2f/%+.2f Y:%+.2f L:%d/%d" % [
		gear,
		rpm,
		speed,
		throttle * 100.0,
		brake * 100.0,
		clutch * 100.0,
		steer,
		steer_angle,
		drive_wheels,
		steer_wheels,
		path_open,
		rotation_center,
		com_x,
		com_y,
		com_z,
		yaw_rate,
		predicted_locked,
		axle_locked,
	]

func _monitor_config(title: String, y_min: float, y_max: float, series: Array, h_lines: Dictionary) -> Dictionary:
	var config: Dictionary = {
		"y_min": y_min,
		"y_max": y_max,
		"window_duration": 4.0,
		"title": title,
		"series": series,
		"h_lines": h_lines,
		"v_lines": {0.0: "0", 1.0: "1", 2.0: "2", 3.0: "3"},
		"use_particles": true,
	}
	return config

func _series(y_key: String, color: Color, trail_width: float) -> Dictionary:
	var config: Dictionary = {
		"y_key": y_key,
		"color": color,
		"size": 1.0,
		"solid_time": 0.3,
		"fade_time": 1.2,
		"trail_mode": 1,
		"trail_width": trail_width,
	}
	return config
