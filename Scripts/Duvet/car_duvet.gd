class_name CarDuvet
extends RigidBody3D

@export_file("*.json") var replay_path: String = ""
@export var action_strength: float = 30000

@onready var chassis: ChassisDuvet = $Chassis
@onready var engine: EngineDuvet = $Engine
@onready var transmission: TransmissionDuvet = $Transmission
@onready var welded_diff: WeldedDiffDuvet = $WeldedDiff

var input_agent: InputAgent
var throttle_input: float = 0
var brake_input: float = 0
#var clutch_input: float = 0
var steer: float = 0

var wheels_load: float = 0

func _ready() -> void:
	if replay_path:
		input_agent = ReplayAgent.new()
		input_agent.replay_path = replay_path
	else: input_agent = PlayerAgent.new()
	get_tree().root.add_child.call_deferred(input_agent)
	get_tree().root.move_child.call_deferred(input_agent, 0)
	input_agent.start()

func _input(event: InputEvent) -> void:
	#if event.is_action("throttle"):
		#throttle_input = event.get_action_strength("throttle")
	#if event.is_action("brake"):
		#brake_input = event.get_action_strength("brake")
	#if event.is_action("clutch"):
	#	clutch_input = 1 - event.get_action_strength("clutch")
	#if event.is_action_pressed("gear up"):
		#transmission.gear_up()
	#if event.is_action_pressed("gear down"):
		#transmission.gear_down()
	if event.is_action_pressed("reset"):
		car_reset()

func _physics_process(delta: float) -> void:
	if input_agent.get_strength(Lib.InputType.GEAR_UP) > 0.0:
		transmission.gear_up()
	if input_agent.get_strength(Lib.InputType.GEAR_DOWN) > 0.0:
		transmission.gear_down()
	#print(input_agent.get_strength(Lib.InputType.GEAR_UP))
	
	var steer_input = -input_agent.get_strength(Lib.InputType.STEER)
	if abs(steer) < 1:
		steer += 3 * delta * steer_input
	else:
		steer = clamp(steer, -1, 1)
	steer *= pow(2, -5 * delta)
	chassis.set_steer(steer)
	var action_input = Vector2(Input.get_axis("action_down", "action_up"), Input.get_axis("action_left", "action_right"))
	var action_force = Vector3()
	action_force += global_basis.x * action_input.x * action_strength
	action_force += global_basis.z * action_input.y * action_strength
	apply_central_force(action_force)
	DebugDraw3D.draw_arrow_ray(to_global(center_of_mass), action_force, 0.001, Color.FOREST_GREEN, 0.1)
	var drive_wheels_omega: Array[float] = chassis.get_drive_wheels_omega()
	var drive_wheels_internal_torques: Array[float] = chassis.get_drive_wheels_internal_torques()
	var diff_omega = welded_diff.get_omega(drive_wheels_omega)

	var engine_omega = engine.get_omega()
	var diff_ratio = welded_diff.ratio
	var drivetrain_inertia_moment = 2*chassis.get_drive_wheels_inertia_moment()[0]/pow(diff_ratio,2) \
			+ welded_diff.inertia_moment
	var engine_inertia_moment = engine.get_inertia_moment()
	
	var sync_torque = transmission.get_sync_torque(drivetrain_inertia_moment, engine_inertia_moment,
		diff_omega, engine_omega, delta)
	#var sync_torque = 0
	engine.update_engine_omega(delta, input_agent.get_strength(Lib.InputType.THROTTLE), sync_torque)
	#var engine_torque = engine.get_torque(delta, input_agent.get_strength(Lib.InputType.THROTTLE), sync_torque)
	#var engine_torque = engine.get_torque_at_omega(
			#delta, input_agent.get_strength(Lib.InputType.THROTTLE), transmission_back_omega)
	#var torque_to_diff = transmission.get_forward_torque(sync_torque)
	#var torque_to_wheel = welded_diff.get_one_wheel_torque(torque_to_diff)
	var drive_wheel_omega_delta = welded_diff.get_drive_wheel_omega_delta(delta,
		sync_torque, drive_wheels_internal_torques, drivetrain_inertia_moment)
	var wheel_res_forces: Dictionary[Vector3, Vector3] = chassis.get_res_forces(
		delta, drive_wheel_omega_delta, input_agent.get_strength(Lib.InputType.BRAKE), drivetrain_inertia_moment)
	for i in wheel_res_forces.keys():
		var hub_pos = i
		var hub_force = wheel_res_forces[i]
		apply_force(hub_force, hub_pos - global_position)
	wheels_load = 0 #update somewhere here
	
	#chassis.update_all_wheels_omega(delta, drive_wheel_omega_delta)
	
	chassis.update_all_wheels_basis()

func get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func car_reset() -> void:
	global_position += Vector3(0, 3, 0)
	rotation.x = 0
	rotation.z = 0
	linear_velocity = Vector3()
	angular_velocity = Vector3()
