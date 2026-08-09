class_name CarFlos
extends RigidBody3D

@export_file("*.json") var replay_path: String = ""

@export var chassis: ChassisFlos
@export var engine: EngineFlos
@export var transmission: TransmissionFlos
@export var steer_G: float = 1
@export var steering: float = 20
@export var steer_easing: float = 0.1
@export var lateral_traction: float = 100
@export var drift_angle: float = 60
@export var drift_flick_speed: float = 60
@export var drift_flick_damp: float = 16
@export var drift_front_balance: float = 0.3
@export var drift_speed_retention: float = 0.7
@export var air_stab_speed: float = 4
@export var air_stab_damp: float = 2
@export var barrel_stab_speed: float = 20
@export var barrel_stab_damp: float = 8
@export var drift_force: float = 2.0
@export var braking_force: float = 10000
@export var air_control: float = 5
@export var undrift_speed: float = 10
@export var undrift_angle: float = 20
@export var barrel_min_velocity: float = 0.0
@export var barrel_margin_degrees: float = 150
@export var barrel_safe_time: float = 0.1
@export var barrel_greed_limit: float = 1.8
@export var turnaround_speed: float = 0.075
@export var heli_stab_speed: float = 20
@export var heli_stab_damp: float = 8
@export var brake_tap_max_time: float = 0.25

var in_air: bool = false
var is_drifting: bool = false
var is_stabilizing: bool = false
var input_agent: InputAgent
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var state: int = 0
var time_to_land: float = 0
var liftoff_velocity: Vector3

var _accumulated_rotation: float = 0.0
var _prev_perp: Vector3 = Vector3.ZERO
var _turn_count: int = 0
var _first_rotation: bool = true
var _reconsider_barrel: bool = true
var _turnaround_forward: Vector3
var _turnaround_progress: float
var _turnaround_clockwise: int
var _brake_tap: bool
var _brake_strength: float
var _brake_press_time: float
var _brake_tap_released: bool

@onready var front_pivot: Node3D = $Pivots/FrontPivot
@onready var rear_pivot: Node3D = $Pivots/RearPivot
@onready var ground_contact: RayCast3D = $GroundContact
@onready var ballistic_calculator: BallisticCalculator = $BallisticCalculator
@onready var air_postpone: Timer = $AirPostpone
@onready var brake_tap: Timer = $BrakeTap
@onready var straight_steer: Timer = $StraightSteer

enum states {
	GRIP,
	AIR,
	BARREL,
	TURNAROUND,
	HELI,
	REVERSE,
}

func _ready() -> void:
	if replay_path:
		input_agent = ReplayAgent.new()
		input_agent.replay_path = replay_path
	else: input_agent = PlayerAgent.new()
	get_tree().root.add_child.call_deferred(input_agent)
	get_tree().root.move_child.call_deferred(input_agent, 0)
	input_agent.start()
	
	if inertia.is_zero_approx():
		inertia = Lib.calculate_aabb_inertia(self)
	
	transmission.calculate_gears\
			(Lib.rpm_to_omega(engine.get_engine_redline()))
	
	ballistic_calculator.acceleration_z = air_control
	ballistic_calculator.acceleration_x = 0
	braking_force *= mass / 1000

func get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func _physics_process(delta: float) -> void:
	#print("%4.1f KM/H" % Lib.ms_to_kmh(linear_velocity.length()))
	_update_brake_input_state(delta)
	_process_current_state(delta)
	_update_straight_steer_timer()
	chassis.set_wheels_speed(linear_velocity.length(), is_drifting)
	_update_drive_wheel_smoke()


func _process_current_state(delta: float) -> void:
	match state:
		states.GRIP:
			if handle_grip_transitions():
				_process_ground_drive()
		states.AIR:
			if handle_air_transitions():
				time_to_land -= delta
				_process_air_drive()
		states.REVERSE:
			if handle_reverse_transitions():
				reverse_process()
		states.BARREL:
			if handle_barrel_transitions():
				time_to_land -= delta
				barrel_process()
		states.TURNAROUND:
			if handle_turnaround_transitions():
				turnaround_process()
		states.HELI:
			if handle_heli_transitions():
				time_to_land -= delta
				heli_process()


func _change_state(next_state: int, context: Dictionary = {}) -> void:
	if state == next_state:
		return
	state = next_state
	_enter_state(next_state, context)


func _enter_state(next_state: int, context: Dictionary) -> void:
	match next_state:
		states.GRIP:
			in_air = false
		states.TURNAROUND:
			in_air = false
			if context.get("start_turnaround", false):
				_turnaround_forward = Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
				_turnaround_progress = Lib.signed_angle_around_axis(linear_velocity, global_basis.x, Vector3.DOWN)
				_turnaround_clockwise = int(sign(-input_agent.get_strength(Lib.InputType.STEER)))
				if _turnaround_clockwise == 0:
					_turnaround_clockwise = 1
		states.BARREL:
			_prev_perp = global_basis.y
			_accumulated_rotation = 0.0
			_turn_count = 0
			_first_rotation = true
			_reconsider_barrel = true


func _process_ground_drive() -> void:
	if is_drifting:
		drift_process(is_stabilizing)
	else:
		grip_process()


func _process_air_drive() -> void:
	if is_drifting:
		airdrift_process(is_stabilizing)
	else:
		air_process()


func _update_drive_wheel_smoke() -> void:
	var smoke_ratio = 0.0
	if is_drifting and not in_air and ground_contact.is_colliding() and linear_velocity.length_squared() > 0.001:
		var alignment = abs(global_basis.x.normalized().dot(linear_velocity.normalized()))
		smoke_ratio = 4 * (1.0 - clamp(alignment, 0.0, 1.0))
	chassis.set_drive_wheels_smoke_ratio(smoke_ratio)


func _update_brake_input_state(delta: float) -> void:
	var was_pressed = _brake_strength > 0.0
	_brake_strength = input_agent.get_strength(Lib.InputType.BRAKE)
	var is_pressed = _brake_strength > 0.0
	_brake_tap_released = was_pressed and not is_pressed and _brake_press_time <= brake_tap_max_time
	if is_pressed:
		_brake_press_time += delta
	else:
		_brake_press_time = 0.0


func should_steer_wheels_by_velocity() -> bool:
	return state == states.GRIP or state == states.REVERSE or state == states.AIR


func get_turnaround_wheel_steer_sign() -> float:
	return float(_turnaround_clockwise) if state == states.TURNAROUND else 0.0


func _update_straight_steer_timer() -> void:
	if state == states.GRIP and is_drifting and not is_stabilizing and _is_straight_for_undrift():
		if straight_steer.is_stopped():
			straight_steer.start()
	else:
		straight_steer.stop()


func _is_straight_for_undrift() -> bool:
	var planar_velocity = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var planar_forward = Vector3(global_basis.x.x, 0.0, global_basis.x.z)
	if planar_velocity.length_squared() < 0.001 or planar_forward.length_squared() < 0.001:
		return false
	var straight_angle = abs(Lib.signed_angle_around_axis(
			planar_velocity.normalized(),
			planar_forward.normalized(),
			Vector3.UP
	))
	return straight_angle <= deg_to_rad(undrift_angle)


func get_body_force(lower_gear: bool = false, redline_margin: float = 1000) -> float:
	var engine_omega = get_engine_omega(lower_gear)
	if lower_gear and Lib.omega_to_rpm(engine_omega) + redline_margin > engine.get_engine_redline():
		return 0
	var engine_torque = engine.get_torque_at_omega\
			(engine_omega, input_agent.get_strength(Lib.InputType.THROTTLE))
	var body_force = transmission.get_torque_to_body(engine_torque, lower_gear)
	return body_force


func get_engine_omega(lower_gear: bool = false) -> float:
	return transmission.get_omega_to_engine\
			(linear_velocity.length() * sign(linear_velocity.dot(global_basis.x)), lower_gear)


func handle_forward_transmission() -> void:
	var engine_omega = get_engine_omega()
	if Lib.omega_to_rpm(engine_omega) > engine.get_engine_redline() - 100:
		transmission.gear_up()
	elif get_body_force(true) > get_body_force():
		transmission.gear_down()


func handle_grip_transitions() -> bool:
	if in_air:
		if abs(angular_velocity.z) > barrel_min_velocity:
			_change_state(states.BARREL)
			barrel_process()
			return false
		_change_state(states.AIR)
		_process_air_drive()
		return false
	if not ground_contact.is_colliding():
		if air_postpone.is_stopped():
			lift_off()
	if _brake_tap_released:
		if is_drifting:
			is_stabilizing = true
		else:
			is_drifting = true
		if _brake_tap:
			_change_state(states.TURNAROUND, {"start_turnaround": true})
			turnaround_process()
			return false
		else:
			brake_tap.start()
			_brake_tap = true
	if linear_velocity.dot(global_basis.x) < 0.2 and _brake_strength > 0.0:
		_change_state(states.REVERSE)
		return false
	if linear_velocity.length() < undrift_speed and is_drifting:
		is_stabilizing = true
	return true


func grip_process() -> void:
	handle_forward_transmission()
	var body_force = get_body_force()
	apply_central_force(global_basis.x * body_force)
	apply_central_force(_brake_strength * -linear_velocity.normalized() * braking_force)
	grip_handling()

func barrel_process() -> void:
	handle_forward_transmission()
	air_sideway()
	barrel_stab()
	barrel_oversee()

func heli_process() -> void:
	handle_forward_transmission()
	air_sideway()
	heli_stab()
	_turnaround_progress += angular_velocity.dot(Vector3.DOWN) / Engine.physics_ticks_per_second

func grip_handling() -> void:
	var front_lateral_force = -get_point_velocity(front_pivot.global_position).dot(global_basis.z) * global_basis.z * lateral_traction * mass / 2
	var front_steer: Vector3 = input_agent.get_strength(Lib.InputType.STEER) * get_point_velocity(front_pivot.global_position).dot(global_basis.x) * global_basis.z * \
			lateral_traction * sin(deg_to_rad(steering)) * mass / 2
	front_steer += front_lateral_force
	var front_limit: float = mass * gravity / front_steer.length()
	if front_limit < 1:
		front_steer *= front_limit
		apply_central_force(-linear_velocity.normalized() * braking_force * (1-front_limit))
	apply_force(front_steer, \
			front_pivot.global_position - global_position)
	var rear_lateral_force = -get_point_velocity(rear_pivot.global_position).dot(global_basis.z) * global_basis.z * lateral_traction * mass / 2
	apply_force(rear_lateral_force, \
			rear_pivot.global_position - global_position)


func drift_process(stabilizing: bool) -> void:
	handle_forward_transmission()
	var body_force = get_body_force()
	drift_body_torque(stabilizing)
	var front_lateral_force = -linear_velocity.dot(global_basis.z) * global_basis.z * \
			drift_front_balance * drift_force * mass
	var rear_lateral_force = linear_velocity.dot(global_basis.z) * global_basis.z * \
			(1-drift_front_balance) * drift_force * mass
	var side_vel = linear_velocity.dot(global_basis.z)
	var lateral_dissipation = side_vel * side_vel * (drift_force * mass)
	var fwd_speed = linear_velocity.dot(global_basis.x)
	
	var compensate_force = 0.0
	if fwd_speed > 0.1:
		compensate_force = (lateral_dissipation / fwd_speed) * drift_speed_retention
	
	apply_central_force(global_basis.x * (body_force + compensate_force))
	apply_central_force(_brake_strength * -linear_velocity.normalized() * braking_force)
	apply_force(front_lateral_force, \
			front_pivot.global_position - global_position)
	apply_force(-rear_lateral_force, \
			rear_pivot.global_position - global_position)


func handle_air_transitions() -> bool:
	if ground_contact.is_colliding():
		_change_state(states.GRIP)
		_process_ground_drive()
		return false
	if _brake_tap_released:
		if is_drifting:
			is_stabilizing = true
		else:
			is_drifting = true
	return true

func handle_barrel_transitions() -> bool:
	if ground_contact.is_colliding():
		_change_state(states.GRIP)
		grip_process()
		return false
	if _reconsider_barrel:
		var current_spin_rate = angular_velocity.dot(Vector3(liftoff_velocity.x, 0, liftoff_velocity.z).normalized())
		var time_for_one_more = (TAU / abs(current_spin_rate)) if current_spin_rate != 0 else INF
		if time_to_land < barrel_greed_limit or \
				time_to_land < (time_for_one_more + barrel_safe_time):
			_change_state(states.AIR)
			air_process()
			return false
		else: _reconsider_barrel = false
	return true

func handle_heli_transitions() -> bool:
	if ground_contact.is_colliding():
		_change_state(states.TURNAROUND)
		turnaround_process()
		return false
	return true

func air_process() -> void:
	handle_forward_transmission()
	air_sideway()
	air_stab()


func airdrift_process(stabilizing: bool = false) -> void:
	handle_forward_transmission()
	air_sideway()
	var forward_vel = Vector3(liftoff_velocity.x, 0, liftoff_velocity.z)
	air_stab(
		forward_vel.rotated(Vector3(0, 1, 0),
		-input_agent.get_strength(Lib.InputType.STEER) * deg_to_rad(drift_angle))
	)


func air_sideway() -> void:
	var air_slide_vector = -(liftoff_velocity.cross(Vector3(0, 1, 0))).normalized()
	apply_central_force(-input_agent.get_strength(Lib.InputType.STEER) * \
			mass * air_slide_vector * air_control)


func drift_body_torque(stabilizing: bool = false) -> void:
	var car_slip_angle = Lib.signed_angle_around_axis(linear_velocity, global_basis.x, global_basis.y)
	var target_rear_angle: float = 0.0
	if not stabilizing:
		target_rear_angle = -input_agent.get_strength(Lib.InputType.STEER) * deg_to_rad(drift_angle)
	var error = target_rear_angle - car_slip_angle
	var torque = (drift_flick_speed * error - drift_flick_damp * angular_velocity.y) * mass
	apply_torque(torque * global_basis.y)
	if stabilizing and abs(error) < 0.1:
		is_stabilizing = false
		is_drifting = false

func air_stab(modified_forward: Vector3 = Vector3(0,0,0)) -> void:
	var vel: Vector3 = liftoff_velocity
	var horiz_vel: Vector3 = Vector3(vel.x, 0.0, vel.z)
	if horiz_vel.length_squared() < 0.001:
		return
	var target_forward: Vector3
	if modified_forward:
		target_forward = modified_forward
	else:
		target_forward = horiz_vel.normalized()
	var target_up: Vector3 = Vector3.UP
	var target_right: Vector3 = target_up.cross(target_forward).normalized()
	var target_basis: Basis = Basis(-target_forward, -target_up, target_right)
	var current_basis: Basis = global_transform.basis
	var current_quat: Quaternion = current_basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var delta_quat: Quaternion = target_quat * current_quat.inverse()
	if delta_quat.w < 0.0:
		delta_quat = -delta_quat
	var sin_half_angle: float = sqrt(1.0 - delta_quat.w * delta_quat.w)
	if sin_half_angle > 0.0001:
		var axis: Vector3 = Vector3(delta_quat.x, delta_quat.y, delta_quat.z) / sin_half_angle
		var angle: float = 2.0 * acos(delta_quat.w)
		var orientation_error: Vector3 = axis * angle
		var torque: Vector3 = (orientation_error * air_stab_speed \
				- angular_velocity * air_stab_damp) * mass
		apply_torque(torque)

func barrel_stab() -> void:
	var vel: Vector3 = liftoff_velocity
	if vel.length_squared() < 0.001:
		return
	
	var target_forward: Vector3 = Vector3(vel.x, 0.0, vel.z).normalized()
	
	var current_forward: Vector3 = global_basis.x.normalized()
	
	DebugDraw3D.draw_arrow_ray(global_position, global_basis.x, 10, Color.CORNFLOWER_BLUE, 0.1)
	DebugDraw3D.draw_arrow_ray(global_position, target_forward, 20, Color.HOT_PINK, 0.1)
	var dot = clamp(current_forward.dot(target_forward), -1.0, 1.0)
	var angle_error = acos(dot)
	
	var long_axis: Vector3 = target_forward
	var perp_angular: Vector3 = angular_velocity - long_axis * angular_velocity.dot(long_axis)
	
	if angle_error < 0.001:
		apply_torque(-perp_angular * barrel_stab_damp)
		return
	
	var cross = current_forward.cross(target_forward)
	var rotation_axis = cross.normalized()
	
	var ang_vel_along_axis = angular_velocity.dot(rotation_axis)
	var align_torque = rotation_axis * (angle_error * barrel_stab_speed - ang_vel_along_axis * barrel_stab_damp)
	
	var stability_torque = -perp_angular * barrel_stab_damp
	var total_torque = (align_torque + stability_torque) * mass
	
	apply_torque(total_torque)

func heli_stab() -> void:
	var vel: Vector3 = liftoff_velocity
	if vel.length_squared() < 0.001:
		return
	
	var current_up: Vector3 = global_basis.y.normalized()
	
	DebugDraw3D.draw_arrow_ray(global_position, global_basis.y, 10, Color.CORNFLOWER_BLUE, 0.1)
	DebugDraw3D.draw_arrow_ray(global_position, Vector3.UP, 20, Color.HOT_PINK, 0.1)
	
	var dot = clamp(current_up.dot(Vector3.UP), -1.0, 1.0)
	var angle_error = acos(dot)
	
	var perp_angular: Vector3 = angular_velocity - Vector3.UP * angular_velocity.dot(Vector3.UP)
	
	if angle_error < 0.001:
		apply_torque(-perp_angular * barrel_stab_damp)
		return
	
	var cross = current_up.cross(Vector3.UP)
	var rotation_axis = cross.normalized()
	
	var ang_vel_along_axis = angular_velocity.dot(rotation_axis)
	var align_torque = rotation_axis * (angle_error * heli_stab_speed - ang_vel_along_axis * heli_stab_damp)
	
	var stability_torque = -perp_angular * barrel_stab_damp
	var total_torque = (align_torque + stability_torque) * mass
	
	apply_torque(total_torque)

func handle_reverse_transitions() -> bool:
	if not ground_contact.is_colliding():
		lift_off()
		_change_state(states.AIR)
		air_process()
		return false
	if linear_velocity.dot(global_basis.x) > -0.2 and \
			input_agent.get_strength(Lib.InputType.THROTTLE) > 0.0:
		_change_state(states.GRIP)
		transmission.gear_up()
		return false
	return true

func handle_turnaround_transitions() -> bool:
	if in_air:
		_change_state(states.HELI)
		heli_process()
		return false
	if not ground_contact.is_colliding():
		if air_postpone.is_stopped():
			lift_off()
	var car_forward_proj = Vector3(global_basis.x.x, 0, global_basis.x.z).normalized()
	if abs(_turnaround_progress) >= TAU \
			and car_forward_proj.dot(_turnaround_forward) > 0.95:
		is_drifting = false
		is_stabilizing = false
		_change_state(states.GRIP)
		grip_process()
		return false
	return true

func reverse_process() -> void:
	transmission.set_reverse()
	var engine_omega = get_engine_omega()
	var engine_torque = engine.get_torque_at_omega\
			(engine_omega, _brake_strength)
	var body_force = transmission.get_torque_to_body(engine_torque)
	apply_central_force(global_basis.x * body_force)
	apply_central_force(input_agent.get_strength(Lib.InputType.THROTTLE) \
			* -linear_velocity.normalized() * braking_force)
	grip_handling()

func turnaround_process() -> void:
	_turnaround_progress -= turnaround_speed * _turnaround_clockwise
	var target_forward = _turnaround_forward.rotated(Vector3.DOWN, _turnaround_progress)
	DebugDraw3D.draw_arrow_ray(global_position, target_forward * 100, 0.1)
	var car_forward_proj = Vector3(global_basis.x.x, 0, global_basis.x.z).normalized()
	DebugDraw3D.draw_arrow_ray(global_position, car_forward_proj * 100, 0.1, Color.BROWN)
	var error = Lib.signed_angle_around_axis(target_forward, car_forward_proj, Vector3.DOWN)
	var torque = (drift_flick_speed * error - drift_flick_damp * angular_velocity.dot(Vector3.UP)) * mass
	apply_torque(torque * Vector3.UP)

func calculate_time_to_land() -> float:
	ballistic_calculator.start_position = position
	ballistic_calculator.initial_velocity = linear_velocity
	return ballistic_calculator.find_collision_time()

func lift_off() -> void:
	air_postpone.wait_time = clamp(3/linear_velocity.length(), 0, 0.5)
	air_postpone.start()

func barrel_oversee() -> void:
	if linear_velocity.length_squared() < 0.001:
		return
	
	var current_axis: Vector3 = global_basis.x.normalized()
	
	var current_perp: Vector3 = global_basis.y
	current_perp -= current_perp.dot(current_axis) * current_axis
	if current_perp.length_squared() < 0.001:
		current_perp = global_basis.z - global_basis.z.dot(current_axis) * current_axis
	current_perp = current_perp.normalized()
	
	if _prev_perp.is_zero_approx():
		_prev_perp = current_perp
		return
	
	var cross_vec: Vector3 = _prev_perp.cross(current_perp)
	var sin_theta: float = cross_vec.dot(current_axis)
	var cos_theta: float = _prev_perp.dot(current_perp)
	var delta_angle: float = atan2(sin_theta, cos_theta)
	
	_accumulated_rotation += delta_angle
	_prev_perp = current_perp
	var margin_rad: float = deg_to_rad(barrel_margin_degrees)
	var direction: float = sign(_accumulated_rotation)
	
	if direction == 0.0:
		return
	
	if _first_rotation:
		var first_threshold: float = TAU - margin_rad
		if abs(_accumulated_rotation) >= first_threshold:
			_turn_count += int(direction)
			_accumulated_rotation -= direction * first_threshold
			_first_rotation = false
			_reconsider_barrel = true
	else:
		if abs(_accumulated_rotation) >= TAU:
			_turn_count += int(direction)
			_accumulated_rotation -= direction * TAU
			_reconsider_barrel = true


func _on_air_postpone_timeout() -> void:
	in_air = true
	liftoff_velocity = linear_velocity
	time_to_land = calculate_time_to_land()


func _on_brake_tap_timeout() -> void:
	_brake_tap = false


func _on_straight_steer_timeout() -> void:
	if state == states.GRIP and is_drifting and not is_stabilizing and _is_straight_for_undrift():
		is_stabilizing = true
