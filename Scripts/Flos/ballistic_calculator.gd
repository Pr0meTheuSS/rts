class_name BallisticCalculator
extends Node3D

# ===================== ВХОДНЫЕ ПАРАМЕТРЫ =====================
var start_position: Vector3 = Vector3.ZERO
var initial_velocity: Vector3 = Vector3.ZERO
var gravity: float = 9.8
var acceleration_z: float = 0.0		# боковое ускорение (только для расширения shapecast)
var acceleration_x: float = 0.0		# продольное ускорение (только для расширения shapecast)
var sea_level: float = 0.0

# Шейпкаст
@export var collision_mask_value: int = 4
@export var ignore_distance_from_start: float = 2.0

# ===================== DEBUG НАСТРОЙКИ (меняй в инспекторе НА ЛЕТУ) =====================
@export var debug_visualization: bool = true   # все DebugDraw3D
@export var debug_print: bool = true           # все print() в консоль

var base_shape_size: Vector3 = Vector3(1, 1, 2)

# Внутренние
var shape: BoxShape3D
var search_done: bool = false
var ground_ray: RayCast3D

func _ready():
	shape = BoxShape3D.new()
	shape.size = base_shape_size
	
	ground_ray = RayCast3D.new()
	add_child(ground_ray)
	ground_ray.enabled = true
	ground_ray.collision_mask = 2
	ground_ray.target_position = Vector3.DOWN * 2.0

func _physics_process(_delta):
	if not search_done:
		search_done = true
		start_search()

func _debug_print(msg: String) -> void:
	if debug_print:
		print(msg)

func start_search():
	_debug_print("=== НАЧАЛО ПОИСКА ===")
	_debug_print("Start: " + str(start_position) + " Velocity: " + str(initial_velocity))
	_debug_print("Sea level: " + str(sea_level) + " Ignore distance: " + str(ignore_distance_from_start))
	var t_hit = find_collision_time()
	_debug_print("ИТОГОВОЕ ВРЕМЯ КАСАНИЯ: " + str(t_hit))
	_debug_print("=== ПОИСК ЗАВЕРШЁН ===")

# ===================== АНАЛИТИКА ТРАЕКТОРИИ (без влияния Ax/Az) =====================
func get_position_at_time(t: float) -> Vector3:
	var y = start_position.y + initial_velocity.y * t - 0.5 * gravity * t * t
	var x = start_position.x + initial_velocity.x * t
	var z = start_position.z + initial_velocity.z * t
	return Vector3(x, y, z)

func get_velocity_at_time(t: float) -> Vector3:
	return Vector3(initial_velocity.x, initial_velocity.y - gravity * t, initial_velocity.z)

# ===================== ПАРАМЕТРЫ РАСТУЩЕГО БОКСА — ИСПРАВЛЕНО =====================
func get_shape_params(t: float) -> Dictionary:
	var length_inc = acceleration_x * t * t
	var width_inc = abs(acceleration_z) * t * t
	
	var size = base_shape_size
	size.x += width_inc      # lateral (left + right)
	size.z += length_inc     # forward only
	
	# offset только по длине (вперёд), по ширине остаётся 0 → симметрия
	var offset = Vector3(0, 0, length_inc * 0.5)
	return {"size": size, "offset": offset}

# ===================== ОРИЕНТАЦИЯ БОКСА =====================
func get_shape_transform(pos: Vector3, vel: Vector3, offset: Vector3) -> Transform3D:
	var horiz = Vector3(vel.x, 0, vel.z)
	var orient: Basis
	if horiz.length_squared() > 0.001:
		var forward = horiz.normalized()
		var right = Vector3.UP.cross(forward).normalized()
		var up = forward.cross(right).normalized()
		orient = Basis(right, up, forward)
	else:
		orient = Basis.IDENTITY
	var global_offset = orient * offset
	return Transform3D(orient, pos + global_offset)

# ===================== ШЕЙПКАСТ =====================
func cast_down(t: float, visualize: bool = true) -> bool:
	var pos = get_position_at_time(t)
	var vel = get_velocity_at_time(t)
	
	var params_data = get_shape_params(t)
	var size = params_data.size
	var offset = params_data.offset
	
	var temp_shape = BoxShape3D.new()
	temp_shape.size = size
	
	var trans = get_shape_transform(pos, vel, offset)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = temp_shape
	query.transform = trans
	query.collision_mask = collision_mask_value
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = []
	
	var results = space_state.intersect_shape(query)
	var collided = results.size() > 0
	
	if debug_visualization and visualize:
		var color = Color.YELLOW if not collided else Color.ORANGE
		var dur = 2.0
		DebugDraw3D.draw_box(trans.origin, trans.basis.get_rotation_quaternion(), size, color, true, dur)
		if collided:
			DebugDraw3D.draw_sphere(trans.origin, 0.15, Color.RED, 2.0)
	
	return collided

# ===================== ВРЕМЯ ДО МОРЕ =====================
func get_sea_time() -> float:
	var a = -0.5 * gravity
	var b = initial_velocity.y
	var c = start_position.y - sea_level
	var disc = b * b - 4 * a * c
	if disc < 0:
		return -1.0
	var t1 = (-b + sqrt(disc)) / (2 * a)
	var t2 = (-b - sqrt(disc)) / (2 * a)
	var times = [t1, t2].filter(func(x): return x > 0)
	return times.min() if not times.is_empty() else -1.0

# ===================== ВЫХОД ИЗ СТАРТОВОЙ ЗОНЫ =====================
func get_escape_time() -> float:
	var t_sea = get_sea_time()
	if t_sea <= 0:
		return 0.0
	
	var t = 0.0
	var step = 0.05
	while t < t_sea:
		var pos = get_position_at_time(t)
		ground_ray.global_position = pos + Vector3.UP * 0.5
		ground_ray.force_raycast_update()
		if not ground_ray.is_colliding():
			return t
		t += step
	return t_sea

# ===================== ВРЕМЯ ИГНОРА =====================
func get_ignore_time() -> float:
	if ignore_distance_from_start <= 0.0:
		return 0.0
	var horiz_vel = Vector3(initial_velocity.x, 0, initial_velocity.z)
	var horiz_speed = horiz_vel.length()
	if horiz_speed < 0.001:
		return 0.0
	return ignore_distance_from_start / horiz_speed

# ===================== ОСНОВНОЙ ПОИСК =====================
func find_collision_time() -> float:
	if start_position.y <= sea_level:
		return 0.0
	
	var t_sea = get_sea_time()
	if t_sea <= 0:
		return 0.0
	
	var t_escape = get_escape_time()
	var t_ignore = get_ignore_time()
	var t_start_search = max(t_escape, t_ignore)
	
	_debug_print("Время выхода из стартовой зоны (raycast слой 2): " + str(t_escape))
	_debug_print("Время игнора по дистанции (" + str(ignore_distance_from_start) + "м): " + str(t_ignore))
	_debug_print("ФИНАЛЬНАЯ ТОЧКА СТАРТА ПОИСКА: " + str(t_start_search))
	
	if debug_visualization:
		DebugDraw3D.draw_sphere(start_position, 0.2, Color.GREEN, 3.0)
		DebugDraw3D.draw_sphere(start_position, ignore_distance_from_start, Color.GREEN, 3.0)
		
		var steps_vis = int(t_sea / 0.1) + 1
		for i in range(steps_vis + 1):
			var t_step = i * 0.1
			if t_step > t_sea:
				t_step = t_sea
			var pt = get_position_at_time(t_step)
			DebugDraw3D.draw_sphere(pt, 0.05, Color.CYAN, 3.0)
	
	if t_start_search >= t_sea:
		_debug_print("Объект не покинет стартовую зону/игнор-дистанцию до моря, время = t_sea")
		return t_sea
	
	var scan_count = 30
	var scan_step = (t_sea - t_start_search) / scan_count
	var collision_states = []
	_debug_print("--- Сканирование от " + str(t_start_search) + " до " + str(t_sea) + " ---")
	for i in range(scan_count + 1):
		var t = t_start_search + i * scan_step
		var coll = cast_down(t, true)
		collision_states.append(coll)
		_debug_print("t=" + str(t) + " coll=" + str(coll))
	
	var first_true_index = -1
	for i in range(collision_states.size()):
		if collision_states[i]:
			first_true_index = i
			break
	
	var t_final: float
	if first_true_index == -1:
		_debug_print("Коллизий не найдено до моря, возвращаем t_sea")
		t_final = t_sea
	elif first_true_index == 0:
		_debug_print("ПРЕДУПРЕЖДЕНИЕ: уже коллизия сразу после игнор-дистанции! Увеличьте ignore_distance_from_start")
		t_final = t_start_search
	else:
		var t_start = t_start_search + (first_true_index - 1) * scan_step
		var t_end = t_start_search + first_true_index * scan_step
		_debug_print("Переход от false к true между " + str(t_start) + " и " + str(t_end))
		
		var t_min = t_start
		var t_max = t_end
		var tolerance = 0.005
		var max_iter = 20
		for _i in range(max_iter):
			var t_mid = (t_min + t_max) * 0.5
			if cast_down(t_mid, true):
				t_max = t_mid
			else:
				t_min = t_mid
			if t_max - t_min < tolerance:
				break
		t_final = (t_min + t_max) * 0.5
	
	_debug_print("Уточнение завершено, t_final = " + str(t_final))
	
	if debug_visualization:
		var final_pos = get_position_at_time(t_final)
		var final_vel = get_velocity_at_time(t_final)
		var final_params = get_shape_params(t_final)
		var final_trans = get_shape_transform(final_pos, final_vel, final_params.offset)
		DebugDraw3D.draw_box(final_trans.origin, final_trans.basis.get_rotation_quaternion(), final_params.size, Color.RED, true, 5.0)
	
	return t_final
