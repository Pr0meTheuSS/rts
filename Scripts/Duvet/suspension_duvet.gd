class_name SuspensionDuvet
extends Node3D

@export var to_debug: bool = false
@export var wheel_radius: float = 0.2
@export var rest_length: float = 0.5
@export var stiffness: float = 40000
@export var damping_compression: float = 2500
@export var damping_relaxation: float = 2800
@export var is_drive: bool
@export var is_steer: bool
@export var longitudinal_friction: float = .7
@export var lateral_friction: float = .3
@export var max_lateral_force: float = 3000
#@export var drive_factor: float
@export var wheel_inertia_moment: float = .2
#@export var brake_torque: float = 50

@onready var raycast: RayCast3D = $RayCast3D
@onready var wheel: Wheel = $Wheel

var car: CarDuvet
var last_length: float
var brakes: BrakesDuvet

var _wheel_omega: float = 0
var _internal_torque: float = 0

func _ready() -> void:
	raycast.target_position = Vector3(0, -(rest_length + wheel_radius), 0)
	wheel.set_radius(wheel_radius)
	last_length = rest_length
	for child in get_children():
		if child is BrakesDuvet:
			brakes = child
	# WARNING WARNING WARNING
	car = get_parent().get_parent()

func set_steer(steer_input: float) -> void:
	if is_steer:
		rotation_degrees.y = steer_input

func get_upwards_force() -> Vector3:
	if raycast.is_colliding():
		raycast.target_position.y = -(rest_length + wheel_radius)
		var hit_point : Vector3 = raycast.get_collision_point() # GLOBAL
		var normal: Vector3 = raycast.get_collision_normal()
		var current_length = hit_point.distance_to(global_position) - wheel_radius
		var compression = rest_length - current_length if current_length > 0 else rest_length
		compression *= normal.dot(global_transform.basis.y)
		var spring_force = compression * stiffness
		var relative_vel: float
		if last_length == rest_length:
			var world_vel: Vector3 = car.get_point_velocity(hit_point)
			relative_vel = global_transform.basis.y.dot(world_vel)
		else:
			relative_vel = (current_length - last_length) * Engine.physics_ticks_per_second / Engine.time_scale
		var spring_damp_force : float
		if relative_vel < 0:
			spring_damp_force = damping_compression * relative_vel
		else: spring_damp_force = damping_relaxation * relative_vel
		var susp_force: float = spring_force - spring_damp_force
		#if to_debug:
			#print("%8.1f - %8.1f, vel %5.7f, len %5.1f"  % [spring_force, spring_damp_force, relative_vel, current_length] )
		susp_force = clamp(susp_force, 0, INF)
		last_length = current_length
		return normal * susp_force
	else:
		last_length = rest_length
		return Vector3.ZERO

func get_traction_torque(delta: float, vertical_load: float, drivetrain_inertia_moment:float, wheel_omega: float) -> float:
	var rotation_vel: float = wheel_omega * wheel_radius
	var relative_vel: float # продольная скорость автомобиля относительно опоры в точке касания
	if raycast.is_colliding():
		var hit_point : Vector3 = raycast.get_collision_point()
		var world_vel: Vector3 = car.get_point_velocity(hit_point)
		DebugDraw3D.draw_arrow_ray(global_position, world_vel, 1, Color.CRIMSON, 0.1)
		relative_vel = global_transform.basis.x.dot(world_vel)
	else:
		relative_vel = rotation_vel
	var slip_vel: float = rotation_vel - relative_vel
	#if to_debug:
		#print("%s, omega: %6.1f, slip_vel: %6.3f" % [self.name, _wheel_omega, slip_vel])
	var ideal_traction_torque = -(slip_vel * drivetrain_inertia_moment) \
			/ (wheel_radius * delta)
	var friction_moment = vertical_load * longitudinal_friction * wheel_radius
	var real_traction_torque = sign(ideal_traction_torque) * min(friction_moment, abs(ideal_traction_torque))
	#if to_debug:
		#print("%s, omega: %6.1f, id_tq: %6.3f" % [self.name, _wheel_omega, ideal_traction_torque])
	#if to_debug:
		#print("%s, idtract: %6.2f, top: %6.2f, bot: %4.2f" % [self.name, ideal_traction_torque, -(slip_vel * wheel_inertia_moment), (wheel_radius * delta)])
	return real_traction_torque

func get_traction_force(traction_torque: float) -> Vector3:
	var traction_force = Vector3.ZERO
	#if is_drive and raycast.is_colliding():
	if raycast.is_colliding():
		traction_force = -global_transform.basis.x * 10 * traction_torque / wheel_radius
		var projected_force: Vector3 = (traction_force - raycast.get_collision_normal() \
				* traction_force.dot(raycast.get_collision_normal()))
		traction_force = projected_force 
		#print(traction_force)
	return traction_force

func get_lateral_force(vertical_load: Vector3) -> Vector3:
	if raycast.is_colliding():
		var hit_point : Vector3 = raycast.get_collision_point()
		var world_vel: Vector3 = car.get_point_velocity(hit_point)
		var relative_vel := global_transform.basis.z.dot(world_vel)
		var lat_force: Vector3 = global_transform.basis.z * -relative_vel * lateral_friction * vertical_load.length()
		var projected_force: Vector3 = (lat_force - raycast.get_collision_normal() * lat_force.dot(raycast.get_collision_normal()))
		lat_force = projected_force
		if lat_force.length() > max_lateral_force:
			lat_force *= max_lateral_force / lat_force.length()
		return lat_force
	return Vector3(0,0,0)

#func get_brake_force(brake_input: float, wheel_omega: float) -> Vector3:
	#var brake_effort = brakes.get_brake_effort(brake_input, wheel_omega)
	#var brake_force = global_transform.basis.x * brake_effort
	#var projected_force: Vector3 = (brake_force - raycast.get_collision_normal() * brake_force.dot(raycast.get_collision_normal()))
	#return projected_force

func get_brake_torque(brake_input: float, wheel_omega: float):
	return brakes.get_brake_effort(brake_input, wheel_omega)

func get_net_torque(torque:float, traction_torque:float, brake_torque: float):
	var net_torque = torque + traction_torque + brake_torque
	return net_torque

func update_internal_torque(traction_torque:float, brake_torque: float):
	var internal_torque = traction_torque + brake_torque
	_internal_torque = internal_torque

func get_internal_torque() -> float:
	return _internal_torque

#func update_wheel_omega(delta: float, net_torque: float) -> void:
	#_wheel_omega += net_torque * delta / wheel_inertia_moment

#func get_wheel_omega_delta(delta: float, net_torque: float) -> float:
	##if to_debug:
	##	print("%s, omega_delta: %5.0f" % [self.name, net_torque * delta / wheel_inertia_moment])
	#return net_torque * delta / wheel_inertia_moment

func get_wheel_omega() -> float:
	return _wheel_omega

func get_all_forces(delta: float, wheel_omega_delta: float, brake_input: float, drivetrain_inertia_moment:float) -> Vector3:
	raycast.force_raycast_update()
	var upwards_force = get_upwards_force()
	var traction_torque = get_traction_torque(delta, upwards_force.length(), drivetrain_inertia_moment, _wheel_omega)
	var brake_torque = get_brake_torque(brake_input, _wheel_omega)
	update_internal_torque(traction_torque, brake_torque)
	if is_drive:
		_wheel_omega += wheel_omega_delta
	else:
		_wheel_omega += _internal_torque * delta / wheel_inertia_moment
	#if to_debug:
		#print("torq: %5.1f, omeg: %5.1f" % [_internal_torque, _wheel_omega])
	var traction_force = get_traction_force(traction_torque)
	var lateral_force = get_lateral_force(upwards_force)
	#var braking_force = get_brake_force(brake_input, _wheel_omega) * (upwards_force.length()/ 4000)
	DebugDraw3D.draw_arrow_ray(global_position, upwards_force, 0.001, Color.CHARTREUSE, 0.1)
	DebugDraw3D.draw_arrow_ray(global_position+Vector3.UP, traction_force, 0.03, Color.CYAN, 0.1)
	DebugDraw3D.draw_arrow_ray(global_position, lateral_force, 0.01, Color.WEB_PURPLE, 0.1)
	#DebugDraw3D.draw_arrow_ray(global_position, braking_force, 0.01, Color.FIREBRICK, 0.1)
	DebugDraw3D.draw_sphere(raycast.get_collision_point(), 0.2, Color.SEA_GREEN, 0.01)
	var resulting_force = Vector3.ZERO
	resulting_force += upwards_force
	resulting_force += traction_force
	resulting_force += lateral_force
	#resulting_force += braking_force
	return resulting_force

func update_wheel_basis() -> void:
	# Assuming update has been done + non-critical
	#raycast.force_raycast_update()
	# May conflict with on-axis rotation
	wheel.set_omega(_wheel_omega)
	wheel.set_bas(global_transform.basis)
	if raycast.is_colliding():
		var hit_point = raycast.get_collision_point()
		var current_length = hit_point.distance_to(global_position) - wheel_radius
		wheel.set_pos(-global_transform.basis.y * current_length + global_position)
	else:
		wheel.set_pos(-global_transform.basis.y * rest_length + global_position)
