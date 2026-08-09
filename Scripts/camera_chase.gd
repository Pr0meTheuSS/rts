class_name CameraChase
extends Node3D

@export var node_to_follow: RigidBody3D
@export var height: float = 1.25
@export var distance: float = 4.0
@export var orbit_speed: float = 5.0
@export var range_speed: float = 2.0
@export var acceleration_range_factor: float = 0.05

# При скорости ниже этого порога вращение камеры полностью отключается
@export var low_speed_threshold: float = 2.0
# Дополнительное сглаживание дистанции на низкой скорости (0..1)
#@export var low_speed_distance_smoothing: float = 0.2

var prev_velocity: Vector3 = Vector3.ZERO
var current_range: float
var current_yaw: float
var active := true
var camera: Camera3D


func _ready() -> void:
	for child in get_children():
		if child is Camera3D:
			camera = child
			break
	if node_to_follow:
		current_range = distance
		var car_forward := -node_to_follow.global_transform.basis.z
		current_yaw = atan2(car_forward.x, car_forward.z)
		prev_velocity = node_to_follow.linear_velocity


func _physics_process(delta: float) -> void:
	if not active or not node_to_follow or not camera:
		return

	var car: RigidBody3D = node_to_follow
	var vel: Vector3 = car.linear_velocity
	var vel_xz := Vector3(vel.x, 0.0, vel.z)
	var speed := vel_xz.length()

	# --- Вращение (отключается при низкой скорости) ---
	if speed >= low_speed_threshold:
		var target_yaw = atan2(vel.x, vel.z)
		current_yaw = lerp_angle(current_yaw, target_yaw, orbit_speed * delta)
	# else: current_yaw остаётся неизменным – никакого вращения

	# --- Ускорение и дистанция ---
	var accel : Vector3 = (vel - prev_velocity) / max(delta, 0.0001)
	prev_velocity = vel

	var accel_along := 0.0
	if speed > 0.1:
		accel_along = accel.dot(vel_xz.normalized())
	else:
		var fwd := -car.global_transform.basis.z
		var fwd_xz := Vector3(fwd.x, 0.0, fwd.z).normalized()
		if fwd_xz.length() > 0.01:
			accel_along = accel.dot(fwd_xz)

	var target_range := distance + acceleration_range_factor * accel_along
	target_range = max(target_range, 0.5)

	# Доп. сглаживание дистанции на малых скоростях (опционально)
	var dist_factor := 1.0
	#if speed < low_speed_threshold:
	#	dist_factor = lerp(1.0, low_speed_distance_smoothing, 1.0 - speed / low_speed_threshold)
	current_range = lerp(current_range, target_range, range_speed * dist_factor * delta)

	# --- Применяем трансформ камеры ---
	var cam_global := camera.global_transform
	var cam_forward := -cam_global.basis.z
	var pitch := asin(clamp(cam_forward.y, -1.0, 1.0))

	var forward_dir := Vector3(
		sin(current_yaw) * cos(pitch),
		sin(pitch),
		cos(current_yaw) * cos(pitch)
	).normalized()

	var right := Vector3.UP.cross(-forward_dir)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := (-forward_dir).cross(right).normalized()
	var target_basis := Basis(right, up, -forward_dir)

	var behind := Vector3(-sin(current_yaw), 0.0, -cos(current_yaw))
	var target_pos := car.global_position + behind * current_range + Vector3.UP * height

	camera.global_transform = Transform3D(target_basis, target_pos)
