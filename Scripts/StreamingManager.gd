extends Node3D

@export var player_body: PhysicsBody3D
@export_dir var chunks_folder: String = "res://city/"
@export var visibility_map: Array[ChunkMapping] = []

## Слой физических коллизий чанков (обычно 1)
@export_flags_3d_physics var collision_layer_chunks: int = 1

## Слой, на котором находится игрок (для маски триггера)
@export_flags_3d_physics var trigger_mask_layer: int = 3

var chunk_scenes: Dictionary = {}
var chunk_instances: Dictionary = {}
var active_chunk_ids: Array[int] = []

var current_chunk_id: int = -1
var collision_container: Node3D
var triggers_loaded: int = 0

var debug_label: Label3D

const MAX_LOAD_REQUESTS = 3

var pending_loads: Array[Dictionary] = []
var active_loads: int = 0

# ---- ЛОГИРОВАНИЕ ----
var log_file: FileAccess
const LOG_PATH = "user://streaming_log.txt"

var _pending_activate: Array[int] = []
var _activating: bool = false
var loading_chunk_ids: Dictionary = {}
var loading_threads: Dictionary = {}

func _ready():
	# Инициализация лог-файла
	log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_log("=== Streaming Manager started ===")
	
	collision_container = Node3D.new()
	collision_container.name = "CollisionTriggers"
	add_child(collision_container)
	
	debug_label = Label3D.new()
	debug_label.name = "ChunkDebugLabel"
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_label.font_size = 120
	debug_label.outline_size = 10
	debug_label.modulate = Color(1, 1, 0)
	debug_label.hide()
	if player_body:
		player_body.add_child(debug_label)
		debug_label.position = Vector3(0, 1.5, 0)
	else:
		add_child(debug_label)
	
	_log("Starting trigger preparation for chunks 1..50")
	for id in range(1, 51):
		_prepare_chunk_trigger(id)
	
	if visibility_map.is_empty():
		visibility_map.resize(51)
		var default_map = {
			1: [1, 2, 6, 7],
			2: [1, 2, 3],
			3: [2, 3, 4, 9, 10],
			4: [3, 4, 10, 12, 9],
			5: [6, 5, 34, 30, 35],
			6: [1, 7, 6, 5, 9],
			7: [1, 6, 7, 9, 8, 3],
			8: [7, 9, 8, 32, 33, 29],
			9: [7, 8, 9, 10, 3, 6, 33, 1],
			10: [9, 10, 4, 3, 7, 12, 13],
			11: [33, 29, 11, 12, 28, 13],
			12: [11, 13, 4, 12, 14, 10],
			13: [12, 4, 14, 13, 11, 10],
			14: [13, 15, 14, 12],
			15: [13, 14, 15, 19, 16, 21],
			16: [15, 19, 16, 20, 17, 21, 22],
			17: [16, 17, 18, 19],
			18: [17, 18, 25, 26],
			19: [15, 19, 16, 21, 20, 24, 17],
			20: [16, 19, 20, 21, 22, 23, 24, 17],
			21: [19, 21, 23, 24, 20, 22],
			22: [22, 23, 20, 21, 28, 43, 26, 25],
			23: [22, 21, 23, 28, 43, 24, 42, 29, 33, 11],
			24: [23, 24, 22, 21, 19],
			25: [26, 25, 18],
			26: [25, 26, 27],
			27: [26, 27, 41, 40, 42, 43],
			28: [29, 28, 23, 43, 11, 33, 22],
			29: [29, 33, 32, 11, 28, 43, 8, 12],
			30: [5, 34, 30, 31, 44],
			31: [30, 31, 32, 33, 6, 5],
			32: [31, 33, 8, 32, 29, 6],
			33: [31, 32, 33, 8, 29, 28, 11, 12],
			34: [5, 34, 35, 30, 36],
			35: [5, 34, 35, 36, 49],
			36: [34, 35, 36, 49],
			37: [49, 50, 37, 38],
			38: [50, 37, 38, 39],
			39: [38, 39, 40],
			40: [38, 39, 40, 41, 27],
			41: [40, 41, 42, 48, 43, 27],
			42: [48, 42, 43, 28, 23, 41, 40, 27, 47],
			43: [43, 42, 41, 28, 23, 29, 22, 27],
			44: [30, 44, 45, 48],
			45: [44, 45, 48, 42],
			46: [46, 47, 50, 49],
			47: [47, 46, 48, 42],
			48: [47, 42, 48, 45, 44],
			49: [36, 49, 50, 46, 37, 35],
			50: [49, 50, 37, 38, 46],
		}
		for chunk_id in range(1, 51):
			var mapping = ChunkMapping.new()
			var arr: Array[int] = []
			arr.assign(default_map.get(chunk_id, [chunk_id]))
			mapping.chunks = arr
			visibility_map[chunk_id] = mapping
		_log("Visibility map initialized with default values")
	
	_log("_ready() finished, waiting for triggers...")

func _log(msg: String):
	var time_str = Time.get_time_string_from_system()
	var full_msg = "[%s] %s" % [time_str, msg]
	#print(full_msg)
	if log_file:
		log_file.store_line(full_msg)
		log_file.flush()

func _exit_tree():
	if log_file:
		log_file.store_line("[%s] === Streaming Manager stopped ===" % Time.get_time_string_from_system())
		log_file.close()

# ---------- Подготовка триггера ----------
func _prepare_chunk_trigger(chunk_id: int):
	_log("Preparing trigger for chunk %d" % chunk_id)
	var col_path = _get_chunk_path(chunk_id, "_col")
	if col_path.is_empty():
		_log("WARNING: No collision found for chunk %d" % chunk_id)
		return

	_load_scene_async(col_path, func(scene: PackedScene):
		if not scene:
			_log("ERROR: Failed to load collision scene for chunk %d" % chunk_id)
			return

		_log("Collision scene loaded for chunk %d, instantiating..." % chunk_id)
		var temp_instance = scene.instantiate()
		collision_container.add_child(temp_instance)
		await get_tree().process_frame

		if not is_instance_valid(temp_instance):
			_log("WARNING: temp_instance became invalid for chunk %d" % chunk_id)
			return

		var world_aabb := _get_collider_world_aabb(temp_instance)
		if not world_aabb.has_volume():
			world_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.1)
			_log("Chunk %d collider AABB was empty, using fallback" % chunk_id)

		var center_y = world_aabb.get_center().y
		world_aabb.position.y = center_y - 500.0
		world_aabb.size.y = 1000.0

		_create_trigger(chunk_id, world_aabb)
		temp_instance.queue_free()

		triggers_loaded += 1
		_log("Trigger ready for chunk %d (%d/50)" % [chunk_id, triggers_loaded])
		
		if triggers_loaded == 50:
			_log("All 50 triggers ready, scheduling initial activation in 0.5s")
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(_initial_activation)
	)

# ---------- Загрузка с fallback ----------
func _load_scene_async(path: String, on_loaded: Callable):
	if ResourceLoader.has_cached(path):
		_log("Resource already cached: %s" % path)
		on_loaded.call(ResourceLoader.load(path))
		return

	if active_loads >= MAX_LOAD_REQUESTS:
		_log("Queueing async load: %s (active: %d)" % [path, active_loads])
		pending_loads.append({"path": path, "on_loaded": on_loaded})
		return

	if ResourceLoader.load_threaded_request(path):
		active_loads += 1
		_log("Started async load: %s (active: %d)" % [path, active_loads])
		_check_async_load(path, on_loaded)
	else:
		# Асинхронная загрузка не запустилась – используем фоновый поток
		_log("Async load not possible, switching to background thread: %s" % path)
		_load_scene_threaded(path, on_loaded)

func _load_scene_threaded(path: String, on_loaded: Callable):
	var thread = Thread.new()
	var thread_id = path  # использовать путь как ключ
	loading_threads[thread_id] = thread

	var result = null
	thread.start(func():
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is PackedScene:
			return res
		return null
	)

	# Мониторим завершение потока в каждом кадре
	var monitor_timer: Timer = Timer.new()
	monitor_timer.wait_time = 0.05
	monitor_timer.timeout.connect(func():
		if not thread.is_alive():
			var scene = thread.wait_to_finish()
			loading_threads.erase(thread_id)
			if scene:
				_log("Background load completed: %s" % path)
				on_loaded.call(scene)
			else:
				_log("ERROR: Background load failed for: %s" % path)
				on_loaded.call(null)
			monitor_timer.queue_free()
			_process_pending()
	)
	add_child(monitor_timer)
	monitor_timer.start()

func _check_async_load(path: String, on_loaded: Callable):
	var status = ResourceLoader.load_threaded_get_status(path)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var res = ResourceLoader.load_threaded_get(path)
			active_loads -= 1
			_log("Async load completed: %s" % path)
			on_loaded.call(res)
			_process_pending()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var timer = get_tree().create_timer(0.1)
			timer.timeout.connect(_check_async_load.bind(path, on_loaded))
		_:
			_log("ERROR: Async load failed: %s" % path)
			active_loads -= 1
			on_loaded.call(null)
			_process_pending()

func _process_pending():
	while active_loads < MAX_LOAD_REQUESTS and not pending_loads.is_empty():
		var req = pending_loads.pop_front()
		_log("Processing pending load: %s" % req["path"])
		_load_scene_async(req["path"], req["on_loaded"])

# ---------- Триггер ----------
func _create_trigger(chunk_id: int, aabb: AABB):
	_log("Creating trigger area for chunk %d with AABB: %s" % [chunk_id, aabb])
	var area := Area3D.new()
	area.name = "Trigger_" + str(chunk_id)
	area.collision_layer = 0
	area.collision_mask = trigger_mask_layer
	area.monitoring = true
	area.monitorable = false
	area.set_meta("chunk_id", chunk_id)

	var shape := BoxShape3D.new()
	shape.size = aabb.size
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	col_shape.position = aabb.get_center()
	area.add_child(col_shape)

	collision_container.add_child(area)
	area.body_entered.connect(_on_chunk_body_entered.bind(chunk_id))
	_log("Trigger area for chunk %d connected" % chunk_id)

# ---------- AABB ----------
#func _get_visual_aabb_recursive(node: Node) -> AABB:
	#var aabb := AABB()
	#
	## Собственная геометрия узла (в его локальном пространстве)
	#if node is MeshInstance3D and node.mesh:
		#aabb = aabb.merge(node.mesh.get_aabb())      # без node.transform, он применится позже
	#elif node is CSGShape3D:
		#aabb = aabb.merge(node.get_aabb())
	#elif node is CollisionShape3D and node.shape:
		#var shape_aabb := _get_aabb_from_shape(node.shape)
		#if shape_aabb.has_volume():
			#aabb = aabb.merge(node.transform * shape_aabb)   # <-- добавили node.transform
	#elif node is CollisionPolygon3D and node.polygon:
		#var poly_aabb := _get_aabb_from_polygon(node.polygon)
		#if poly_aabb.has_volume():
			#aabb = aabb.merge(node.transform * poly_aabb)     # <-- добавили node.transform
#
	## Обрабатываем детей и переводим их AABB в локальное пространство этого узла
	#for child in node.get_children():
		#var child_aabb := _get_visual_aabb_recursive(child)
		#if child_aabb.has_volume():
			## child.transform переводит из локального пространства ребёнка в локальное пространство родителя
			#aabb = aabb.merge(child.transform * child_aabb)
#
	#return aabb


func _get_collider_world_aabb(root_node: Node) -> AABB:
	var aabb: AABB
	var first := true

	for child in root_node.find_children("*", "CollisionShape3D", true, false):
		if child.shape:
			var shape_aabb := _get_aabb_from_shape(child.shape)
			if shape_aabb.has_volume():
				var world_aabb = child.global_transform * shape_aabb
				if first:
					aabb = world_aabb
					first = false
				else:
					aabb = aabb.merge(world_aabb)

	for child in root_node.find_children("*", "CollisionPolygon3D", true, false):
		if child.polygon:
			var poly_aabb := _get_aabb_from_polygon(child.polygon)
			if poly_aabb.has_volume():
				var world_aabb = child.global_transform * poly_aabb
				if first:
					aabb = world_aabb
					first = false
				else:
					aabb = aabb.merge(world_aabb)

	if first:
		return AABB()   # вообще нет коллизий
	return aabb


func _get_aabb_from_shape(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size * 0.5, shape.size)
	elif shape is SphereShape3D:
		var r = shape.radius
		return AABB(Vector3(-r, -r, -r), Vector3(2*r, 2*r, 2*r))
	elif shape is CylinderShape3D:
		var r = shape.radius
		var h = shape.height
		return AABB(Vector3(-r, -h*0.5, -r), Vector3(2*r, h, 2*r))
	elif shape is CapsuleShape3D:
		var r = shape.radius
		var h = shape.height
		return AABB(Vector3(-r, -(h*0.5 + r), -r), Vector3(2*r, h + 2*r, 2*r))
	elif shape is WorldBoundaryShape3D:
		# Бесконечная плоскость – не вносит вклад в AABB
		return AABB()
	elif shape is ConcavePolygonShape3D or shape is ConvexPolygonShape3D:
		if shape.has_method("get_debug_mesh"):
			return shape.get_debug_mesh().get_aabb()
	# Для всех остальных форм пытаемся получить debug mesh, иначе пусто
	if shape.has_method("get_debug_mesh"):
		return shape.get_debug_mesh().get_aabb()
	return AABB()

func _get_aabb_from_polygon(polygon: CollisionPolygon3D) -> AABB:
	# Вычисляем AABB по всем точкам
	var points = polygon.points
	if points.is_empty():
		return AABB()
	var aabb := AABB(points[0], Vector3.ZERO)
	for p in points:
		aabb = aabb.expand(p)
	return aabb

# ---------- Поиск файла ----------
func _get_chunk_path(chunk_id: int, suffix: String = "") -> String:
	var padded = "%02d" % chunk_id
	var path = chunks_folder + padded + suffix + ".glb"
	if FileAccess.file_exists(path):
		return path
	path = chunks_folder + str(chunk_id) + suffix + ".glb"
	if FileAccess.file_exists(path):
		return path
	return ""


# ---------- Вход игрока в триггер ----------
func _on_chunk_body_entered(body: Node3D, chunk_id: int):
	if debug_label:
		debug_label.text = "Чанк " + str(current_chunk_id)
	if body != player_body:
		return
	if chunk_id == current_chunk_id:
		return

	_log("Player entered trigger of chunk %d (previous: %d)" % [chunk_id, current_chunk_id])
	current_chunk_id = chunk_id
	_update_visibility()

func _on_chunk_loaded(chunk_id: int):
	var idx = _pending_activate.find(chunk_id)
	if idx != -1:
		_pending_activate.remove_at(idx)
	if chunk_id not in active_chunk_ids:
		active_chunk_ids.append(chunk_id)
	_log("Chunk %d fully activated, active_chunk_ids: %s" % [chunk_id, active_chunk_ids])

# ---------- Переключение видимости ----------
func _update_visibility():
	if current_chunk_id == -1:
		_log("_update_visibility called but current_chunk_id == -1, skipping")
		return

	var target_ids: Array[int] = []
	if current_chunk_id < visibility_map.size() and visibility_map[current_chunk_id] != null:
		target_ids = visibility_map[current_chunk_id].chunks
	if target_ids.is_empty():
		target_ids = [current_chunk_id]

	_log("Updating visibility for chunk %d, target list: %s" % [current_chunk_id, target_ids])

	# Деактивируем чанки, которых нет в target_ids
	var to_deactivate: Array[int] = []
	for id in active_chunk_ids:
		if id not in target_ids:
			to_deactivate.append(id)

	_log("Deactivating chunks: %s" % str(to_deactivate))
	for id in to_deactivate:
		_set_chunk_active(id, false)

	# Сразу активируем уже загруженные чанки, которые нужны, но неактивны
	for id in target_ids:
		if chunk_instances.has(id) and id not in active_chunk_ids:
			_log("Activating already loaded chunk %d" % id)
			var inst = chunk_instances[id]
			inst.visible = true
			inst.process_mode = Node.PROCESS_MODE_INHERIT
			if id not in active_chunk_ids:
				active_chunk_ids.append(id)
			# Убираем из очереди, если он там вдруг оказался
			var idx = _pending_activate.find(id)
			if idx != -1:
				_pending_activate.remove_at(idx)

	# Добавляем в очередь активации только те чанки, которых ещё нет в памяти
	for id in target_ids:
		if not chunk_instances.has(id) and id not in _pending_activate:
			_pending_activate.append(id)
			_log("Queued chunk %d for activation" % id)

	# Запускаем обработку очереди, если она не идёт
	if not _activating and not _pending_activate.is_empty():
		_activate_next_chunk()

	_log("Visibility update done. Active: %s, Queued: %s" % [active_chunk_ids, _pending_activate])

func _activate_next_chunk():
	if _pending_activate.is_empty():
		_activating = false
		return
	_activating = true
	var id = _pending_activate[0]
	if loading_chunk_ids.has(id):
		# Уже загружается – ждём следующий кадр и проверяем снова
		await get_tree().process_frame
		_activate_next_chunk()
		return
	_set_chunk_active(id, true)
	await get_tree().process_frame
	_activate_next_chunk()

# ---------- Активация / деактивация чанка ----------
func _set_chunk_active(chunk_id: int, active: bool):
	if active:
		_log("Activating chunk %d" % chunk_id)
		if chunk_instances.has(chunk_id):
			var inst = chunk_instances[chunk_id]
			inst.visible = true
			inst.process_mode = Node.PROCESS_MODE_INHERIT
			if chunk_id not in active_chunk_ids:
				active_chunk_ids.append(chunk_id)
			_log("Chunk %d already instantiated, shown" % chunk_id)
			# Убираем из очереди, если он там был
			var idx = _pending_activate.find(chunk_id)
			if idx != -1:
				_pending_activate.remove_at(idx)
			return
		else:
			# Проверяем, не загружается ли уже
			if loading_chunk_ids.has(chunk_id):
				_log("Chunk %d already loading, waiting" % chunk_id)
				return
			loading_chunk_ids[chunk_id] = true
			var path = _get_chunk_path(chunk_id)
			if path.is_empty():
				_log("ERROR: Main model not found for chunk %d" % chunk_id)
				loading_chunk_ids.erase(chunk_id)
				return
			_log("Loading main scene for chunk %d: %s" % [chunk_id, path])
			_load_scene_async(path, func(main_scene: PackedScene):
				loading_chunk_ids.erase(chunk_id)
				if main_scene == null:
					_log("ERROR: Failed to load main scene for chunk %d" % chunk_id)
					return
				chunk_scenes[chunk_id] = main_scene

				# Если чанк больше не нужен (за время загрузки был удалён из целевых), не инстанцируем
				# Проверяем по наличию в очереди или active_chunk_ids? Безопаснее: если в active_chunk_ids или в очереди.
				var is_needed = (chunk_id in active_chunk_ids) or (chunk_id in _pending_activate)
				if not is_needed:
					_log("Chunk %d no longer needed, not instantiating" % chunk_id)
					return

				_log("Instantiating chunk %d" % chunk_id)
				var instance = main_scene.instantiate()
				instance.name = "Chunk_" + str(chunk_id)
				add_child(instance)
				chunk_instances[chunk_id] = instance
				instance.visible = true
				instance.process_mode = Node.PROCESS_MODE_INHERIT

				_on_chunk_loaded(chunk_id)

				# Загружаем коллизию
				var col_path = _get_chunk_path(chunk_id, "_col")
				if not col_path.is_empty():
					_log("Loading collision for chunk %d: %s" % [chunk_id, col_path])
					_load_scene_async(col_path, func(col_scene: PackedScene):
						if not col_scene:
							_log("ERROR: Failed to load collision scene for chunk %d" % chunk_id)
							return
						if not is_instance_valid(instance):
							_log("WARNING: Instance of chunk %d invalid when adding collision" % chunk_id)
							return
						if chunk_id not in active_chunk_ids and chunk_id not in _pending_activate:
							_log("Chunk %d collision no longer needed" % chunk_id)
							return

						var col_instance = col_scene.instantiate()
						for child in col_instance.get_children():
							if child is CollisionShape3D or child is CollisionPolygon3D or child is PhysicsBody3D:
								child.owner = null
								child.reparent(instance, false)
						col_instance.queue_free()
						_log("Collision added to chunk %d" % chunk_id)
					)
			)
	else:
		_log("Deactivating chunk %d" % chunk_id)
		if chunk_instances.has(chunk_id):
			var inst = chunk_instances[chunk_id]
			inst.visible = false
			inst.process_mode = Node.PROCESS_MODE_DISABLED
		# Удаляем из активных
		var idx = active_chunk_ids.find(chunk_id)
		if idx != -1:
			active_chunk_ids.remove_at(idx)
		# Если был в очереди на активацию – убираем
		idx = _pending_activate.find(chunk_id)
		if idx != -1:
			_pending_activate.remove_at(idx)

# ---------- Начальная активация ----------
func _initial_activation():
	_log("Running initial activation...")
	if not player_body:
		_log("ERROR: No player_body set, cannot initialize")
		return

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = trigger_mask_layer

	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	query.shape = sphere
	query.transform.origin = player_body.global_position

	var results = space_state.intersect_shape(query)
	for result in results:
		var area = result.get("collider")
		if area and area is Area3D:
			current_chunk_id = area.get_meta("chunk_id", -1)
			if current_chunk_id != -1:
				_log("Initial chunk determined: %d" % current_chunk_id)
				_update_visibility()
				if debug_label:
					debug_label.text = "Чанк " + str(current_chunk_id)
				return
	_log("WARNING: Could not determine initial chunk")

# ---------- ТЕСТ ----------
func test_show_first_chunk():
	_log("Test: showing chunk 1")
	active_chunk_ids.append(1)
	_set_chunk_active(1, true)
