class_name SuspensionFlos
extends Node3D

@export var mirror_wheel: bool = false
@export var is_steer: bool
@export var is_drive: bool
@export var wheel_radius: float = 0.335
@export var rest_length: float = 0.2
@export var stiffness: float = 40000
@export var damping: float = 4000
@export var max_visual_steer_angle: float = 45.0
@export var min_visual_steer_speed: float = 0.5

@onready var raycast: RayCast3D = $RayCast3D
@onready var wheel: Wheel = $Wheel

var car: CarFlos
var last_length: float
var wheel_omega: float

func _ready() -> void:
	raycast.target_position = Vector3(0, -(rest_length + wheel_radius), 0)
	wheel.set_radius(wheel_radius)
	last_length = rest_length
	wheel.set_mirror(mirror_wheel)

func _physics_process(_delta: float) -> void:
	raycast.force_raycast_update()
	var upwards_force = get_upwards_force()
	car.apply_force(upwards_force, global_position - car.global_position)
	if is_steer:
		set_steer()
	update_wheel_basis()

func get_upwards_force() -> Vector3:
	if raycast.is_colliding():
		raycast.target_position.y = -(rest_length + wheel_radius)
		var hit_point: Vector3 = raycast.get_collision_point()
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
		var spring_damp_force: float
		spring_damp_force = damping * relative_vel
		var susp_force: float = spring_force - spring_damp_force
		susp_force = clamp(susp_force, 0, INF)
		last_length = current_length
		return normal * susp_force
	else:
		last_length = rest_length
		return Vector3.ZERO

func update_wheel_basis() -> void:
	wheel.set_omega(wheel_omega)
	wheel.set_bas(global_transform.basis)
	if raycast.is_colliding():
		var hit_point = raycast.get_collision_point()
		var current_length = hit_point.distance_to(global_position) - wheel_radius
		wheel.set_pos(-global_transform.basis.y * current_length + global_position)
	else:
		wheel.set_pos(-global_transform.basis.y * rest_length + global_position)

func set_steer() -> void:
	var steer_angle = 0.0
	var turnaround_steer_sign = car.get_turnaround_wheel_steer_sign()
	if car.should_steer_wheels_by_velocity():
		steer_angle = _get_velocity_steer_angle()
	elif turnaround_steer_sign != 0.0:
		steer_angle = deg_to_rad(max_visual_steer_angle) * turnaround_steer_sign
	rotation.y = clamp(steer_angle, -deg_to_rad(max_visual_steer_angle), deg_to_rad(max_visual_steer_angle))

func _get_velocity_steer_angle() -> float:
	var sample_point = raycast.to_global(raycast.target_position)
	var world_vel = car.get_point_velocity(sample_point)
	var planar_vel = car.global_basis.x * world_vel.dot(car.global_basis.x) \
			+ car.global_basis.z * world_vel.dot(car.global_basis.z)
	if planar_vel.length() < min_visual_steer_speed:
		return 0.0
	if planar_vel.dot(car.global_basis.x) < 0.0:
		planar_vel = -planar_vel
	return -Lib.signed_angle_around_axis(planar_vel, car.global_basis.x, global_basis.y)

func set_smoke_ratio(ratio: float) -> void:
	wheel.set_smoke_ratio(ratio if raycast.is_colliding() else 0.0)
