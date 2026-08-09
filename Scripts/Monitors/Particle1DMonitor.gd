class_name Particle1DMonitor
extends BaseParticleMonitor

## ---- Параметры временного графика (осциллограф) ----
var domain_y_min := 0.0
var domain_y_max := 1.0
var window_duration := 5.0          # сколько секунд помещается на экране

var _timer := 0.0
var _max_label_width_y := 0.0
var _max_label_width_x := 0.0

func _ready() -> void:
	_build_ui_common()
	
	_plot_area = _TimePlotArea.new()
	_plot_area.name = "PlotArea"
	_plot_area.size_flags_horizontal = SIZE_EXPAND | SIZE_FILL
	_plot_area.size_flags_vertical   = SIZE_EXPAND | SIZE_FILL
	_plot_area.monitor = self
	_margin_container.add_child(_plot_area)

func configure(config: Dictionary) -> void:
	domain_y_min = config.get("y_min", 0.0)
	domain_y_max = config.get("y_max", 1.0)
	window_duration = config.get("window_duration", 5.0)

	horizontal_lines = config.get("h_lines", {})
	vertical_lines = config.get("v_lines", {})
	title = config.get("title", "")
	poll_interval = config.get("poll_interval", 0.0)
	use_particles = config.get("use_particles", true)

	_title_label.text = title

	# Удаляем старые эмиттеры и ColorRect
	for child in _plot_area.get_children():
		if child is GPUParticles2D or child is ColorRect:
			child.queue_free()

	series.clear()
	if config.has("series"):
		for s_dict in config["series"]:
			var gs = GraphSeries.new()
			gs.from_dict(s_dict)
			series.append(gs)
	else:
		var gs = GraphSeries.new()
		gs.y_source_key = config.get("y_key", "")
		gs.color = config.get("color", Color.WHITE)
		gs.size = config.get("size", 4.0)
		gs.trail_width = config.get("trail_width", 2.0)
		gs.trail_mode = config.get("trail_mode", 1)   # по умолчанию точки+линия
		series.append(gs)

	# Инициализируем историю для всех серий и создаём эмиттеры для точек (если нужно)
	for gs in series:
		gs.history = []   # {time: float, y: float}
		# Эмиттер для движущихся точек (только в режимах 0 и 2)
		if gs.trail_mode in [0, 2] and use_particles:
			var p := GPUParticles2D.new()
			p.amount = 4096
			p.emitting = false
			p.one_shot = false
			p.local_coords = true
			p.trail_enabled = false
			p.lifetime = window_duration
			var mat := ParticleProcessMaterial.new()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.gravity = Vector3.ZERO
			mat.scale_min = gs.size
			mat.scale_max = gs.size
			# Градиент цвета серии без затухания (альфа всегда 1)
			var gradient := Gradient.new()
			gradient.set_color(0, gs.color)
			gradient.set_offset(0, 0.0)
			gradient.set_color(1, gs.color)
			gradient.set_offset(1, 1.0)
			gradient.add_point(1.0, gs.color)
			var tex := GradientTexture1D.new()
			tex.gradient = gradient
			mat.color_ramp = tex
			p.process_material = mat
			_plot_area.add_child(p)
			gs.particles = p
		else:
			gs.particles = null

	# Отступы для подписей горизонтальных и вертикальных линий
	var font := ThemeDB.fallback_font
	var font_size := 12

	_max_label_width_y = 0.0
	for text in horizontal_lines.values():
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > _max_label_width_y:
			_max_label_width_y = w
	var margin_left := int(_max_label_width_y + 8)

	_max_label_width_x = 0.0
	for text in vertical_lines.values():
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > _max_label_width_x:
			_max_label_width_x = w
	var margin_bottom := int(font.get_height(font_size) + 8)

	_margin_container.add_theme_constant_override("margin_left", margin_left)
	_margin_container.add_theme_constant_override("margin_right", margin_left)
	_margin_container.add_theme_constant_override("margin_bottom", margin_bottom)

	_plot_area.queue_redraw()

func _remap_y(value: float) -> float:
	var area := _plot_area.size
	if area.y <= 0.0:
		return 0.0
	return remap(value, domain_y_min, domain_y_max, area.y, 0.0)

func _time_to_x(time_since_now: float) -> float:
	var area_width = _plot_area.size.x
	# time_since_now = 0 → правый край (сейчас), window_duration → левый край (прошлое)
	return remap(time_since_now, 0.0, window_duration, area_width, 0.0)

func _process(delta: float) -> void:
	if _plot_area.size.x <= 0.0 or _plot_area.size.y <= 0.0:
		return

	_timer += delta
	if poll_interval > 0.0 and _timer < poll_interval:
		return
	_timer = 0.0

	var now = Time.get_ticks_msec() / 1000.0
	var area_width = _plot_area.size.x
	var vx = -area_width / window_duration   # скорость влево (px/с)

	for gs in series:
		var y_val = GuiData.get_value(gs.y_source_key)
		if y_val >= domain_y_min and y_val <= domain_y_max:
			var y_pos = _remap_y(y_val)
			# Добавляем новую точку в историю (для линии)
			gs.history.append({"time": now, "y": y_pos})
			# Удаляем точки старше окна
			while gs.history.size() > 0 and gs.history[0].time < now - window_duration:
				gs.history.pop_front()

			# Эмитируем движущуюся точку на правом краю (если режим с точками)
			if gs.trail_mode in [0, 2] and gs.particles:
				var emit_x = _time_to_x(0)   # правый край
				var velocity := Vector2(vx, 0.0)
				gs.particles.emit_particle(
					Transform2D(0.0, Vector2(emit_x, y_pos)),
					velocity,
					gs.color,
					Color(),
					GPUParticles2D.EMIT_FLAG_POSITION | GPUParticles2D.EMIT_FLAG_VELOCITY | GPUParticles2D.EMIT_FLAG_COLOR
				)

	_plot_area.queue_redraw()

# ------------------------------------------------------------
class _TimePlotArea extends Control:
	var monitor: Particle1DMonitor = null

	func _draw() -> void:
		if not monitor:
			return
		var area := Rect2(Vector2.ZERO, size)
		if area.size.x <= 0 or area.size.y <= 0:
			return
		draw_rect(area, Color.WHITE, false)

		var y_min = monitor.domain_y_min
		var y_max = monitor.domain_y_max
		var window = monitor.window_duration
		var font := ThemeDB.fallback_font
		var font_size := 12
		var font_height := font.get_height(font_size)

		# Горизонтальные линии (значения Y)
		for y_val in monitor.horizontal_lines:
			if y_val < y_min or y_val > y_max:
				continue
			var y_px := remap(y_val, y_min, y_max, area.size.y, 0.0)
			draw_line(Vector2(0.0, y_px), Vector2(area.size.x, y_px),
					  Color(Color.WHITE, 0.3))
			var text: String = monitor.horizontal_lines[y_val]
			var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var label_x := -text_width - 4.0
			var label_y := y_px + font_height * 0.2
			draw_string(font, Vector2(label_x, label_y), text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		# Вертикальные линии (время, справа налево)
		for t_val in monitor.vertical_lines:
			if t_val < 0.0 or t_val > window:
				continue
			# t_val – сколько секунд назад (0 = сейчас)
			var x_px := remap(t_val, window, 0.0, 0.0, area.size.x)
			draw_line(Vector2(x_px, 0.0), Vector2(x_px, area.size.y),
					  Color(Color.WHITE, 0.3))
			var text: String = monitor.vertical_lines[t_val]
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var label_pos := Vector2(x_px - text_size.x / 2.0, area.size.y + font_height + 4.0)
			draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		# Отрисовка графиков серий (линии)
		var now = Time.get_ticks_msec() / 1000.0
		for gs in monitor.series:
			if gs.trail_mode in [1, 2] and gs.history.size() >= 2:
				var points: PackedVector2Array = []
				for pt in gs.history:
					var age = now - pt.time
					if age > window:
						continue
					var x = monitor._time_to_x(age)
					points.append(Vector2(x, pt.y))
				if points.size() >= 2:
					draw_polyline(points, gs.color, gs.trail_width)
