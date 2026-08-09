class_name Particle2DMonitor
extends BaseParticleMonitor

## ---- Параметры XY ----
var domain_x_min := 0.0
var domain_x_max := 1.0
var domain_y_min := 0.0
var domain_y_max := 1.0

var _timer := 0.0
var _max_label_width := 0.0

func _ready() -> void:
	_build_ui_common()
	
	_plot_area = PlotArea.new()
	_plot_area.name = "PlotArea"
	_plot_area.size_flags_horizontal = SIZE_EXPAND | SIZE_FILL
	_plot_area.size_flags_vertical   = SIZE_EXPAND | SIZE_FILL
	_plot_area.monitor = self
	_margin_container.add_child(_plot_area)

func configure(config: Dictionary) -> void:
	domain_x_min = config.get("x_min", 0.0)
	domain_x_max = config.get("x_max", 1.0)
	domain_y_min = config.get("y_min", 0.0)
	domain_y_max = config.get("y_max", 1.0)

	vertical_lines = config.get("v_lines", {})
	horizontal_lines = config.get("h_lines", {})
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
		gs.x_source_key = config.get("x_key", "")
		gs.y_source_key = config.get("y_key", "")
		gs.color = config.get("color", Color.WHITE)
		gs.size = config.get("size", 4.0)
		gs.trail_width = config.get("trail_width", 2.0)
		gs.solid_time = config.get("solid_time", 0.5)
		gs.fade_time = config.get("fade_time", 1.0)
		gs.trail_mode = config.get("trail_mode", 1)
		series.append(gs)

	# Создаём эмиттеры для каждой серии (как раньше, с градиентом затухания)
	for gs in series:
		var p := GPUParticles2D.new()
		p.amount = 4096
		p.emitting = false
		p.one_shot = false
		p.local_coords = true
		p.trail_enabled = false

		var lifetime = gs.solid_time + gs.fade_time
		p.lifetime = lifetime

		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		mat.gravity = Vector3.ZERO
		mat.scale_min = gs.size
		mat.scale_max = gs.size

		var gradient := Gradient.new()
		var solid_ratio = gs.solid_time / lifetime
		gradient.set_color(0, gs.color)
		gradient.set_offset(0, 0.0)
		gradient.set_color(1, gs.color)
		gradient.set_offset(1, solid_ratio)
		gradient.add_point(1.0, Color(gs.color.r, gs.color.g, gs.color.b, 0.0))

		var tex := GradientTexture1D.new()
		tex.gradient = gradient
		mat.color_ramp = tex

		p.process_material = mat
		_plot_area.add_child(p)
		gs.particles = p
		gs._prev_plot_pos = Vector2.INF
		gs.trail_segments.clear()

	# Отступы
	var font := ThemeDB.fallback_font
	var font_size := 12
	_max_label_width = 0.0
	for text in horizontal_lines.values():
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > _max_label_width:
			_max_label_width = w
	var margin_side := int(_max_label_width + 8)
	_margin_container.add_theme_constant_override("margin_left", margin_side)
	_margin_container.add_theme_constant_override("margin_right", margin_side)
	_margin_container.add_theme_constant_override("margin_bottom", 30)

	_plot_area.queue_redraw()

func _data_to_plot(x: float, y: float) -> Vector2:
	var area_size := _plot_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return Vector2.INF
	var px := remap(x, domain_x_min, domain_x_max, 0.0, area_size.x)
	var py := remap(y, domain_y_min, domain_y_max, area_size.y, 0.0)
	return Vector2(px, py)

func _process(delta: float) -> void:
	if _plot_area.size.x <= 0.0 or _plot_area.size.y <= 0.0:
		return

	# Очистка трейлов
	var now := Time.get_ticks_msec() / 1000.0
	for gs in series:
		var max_age = gs.solid_time + gs.fade_time
		gs.trail_segments = gs.trail_segments.filter(
			func(seg): return now - seg.birth < max_age
		)

	_timer += delta
	if poll_interval > 0.0 and _timer < poll_interval:
		return
	_timer = 0.0

	for gs in series:
		var x_val = GuiData.get_value(gs.x_source_key)
		var y_val = GuiData.get_value(gs.y_source_key)
		if x_val >= domain_x_min and x_val <= domain_x_max and \
		   y_val >= domain_y_min and y_val <= domain_y_max:
			var plot_pos = _data_to_plot(x_val, y_val)
			_handle_series_point(gs, plot_pos)

	_plot_area.queue_redraw()

func _handle_series_point(gs: GraphSeries, plot_pos: Vector2) -> void:
	# Трейлы (ручная отрисовка)
	if gs.trail_mode in [1, 2]:
		if gs._prev_plot_pos != Vector2.INF:
			gs.trail_segments.append({
				"start": gs._prev_plot_pos,
				"end": plot_pos,
				"birth": Time.get_ticks_msec() / 1000.0,
				"color": gs.color,
				"width": gs.trail_width
			})
		gs._prev_plot_pos = plot_pos
	else:
		gs._prev_plot_pos = Vector2.INF

	# Точки
	if gs.trail_mode in [0, 2] and gs.particles:
		if use_particles:
			gs.particles.emit_particle(
				Transform2D(0.0, plot_pos),
				Vector2.ZERO,
				gs.color,
				Color(),
				GPUParticles2D.EMIT_FLAG_POSITION
			)
		else:
			var dot := ColorRect.new()
			dot.size = Vector2(gs.size, gs.size)
			dot.position = plot_pos - dot.size / 2.0
			dot.color = gs.color
			_plot_area.add_child(dot)
			var tween := create_tween()
			tween.tween_interval(gs.solid_time)
			tween.tween_property(dot, "modulate:a", 0.0, gs.fade_time)
			tween.tween_callback(dot.queue_free)

# ------------------------------------------------------------
class PlotArea extends Control:
	var monitor: Particle2DMonitor = null

	func _draw() -> void:
		if not monitor:
			return
		var area := Rect2(Vector2.ZERO, size)
		if area.size.x <= 0 or area.size.y <= 0:
			return
		draw_rect(area, Color.WHITE, false)

		var domain_x_min = monitor.domain_x_min
		var domain_x_max = monitor.domain_x_max
		var domain_y_min = monitor.domain_y_min
		var domain_y_max = monitor.domain_y_max
		var font := ThemeDB.fallback_font
		var font_size := 12
		var font_height := font.get_height(font_size)

		# Вертикальные линии
		for x_val in monitor.vertical_lines:
			if x_val < domain_x_min or x_val > domain_x_max:
				continue
			var x_px := remap(x_val, domain_x_min, domain_x_max, 0.0, area.size.x)
			draw_line(Vector2(x_px, 0.0), Vector2(x_px, area.size.y),
					  Color(Color.WHITE, 0.3))
			var text: String = monitor.vertical_lines[x_val]
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var label_pos := Vector2(x_px - text_size.x / 2.0, area.size.y + font_height + 4.0)
			draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		# Горизонтальные линии
		for y_val in monitor.horizontal_lines:
			if y_val < domain_y_min or y_val > domain_y_max:
				continue
			var y_px := remap(y_val, domain_y_min, domain_y_max, area.size.y, 0.0)
			draw_line(Vector2(0.0, y_px), Vector2(area.size.x, y_px),
					  Color(Color.WHITE, 0.3))
			var text: String = monitor.horizontal_lines[y_val]
			var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var label_x := -text_width - 4.0
			var label_y := y_px + font_height * 0.2
			draw_string(font, Vector2(label_x, label_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		# Трейлы
		var now := Time.get_ticks_msec() / 1000.0
		for gs in monitor.series:
			for seg in gs.trail_segments:
				var age : int = now - seg.birth
				var max_age = gs.solid_time + gs.fade_time
				if age > max_age:
					continue
				var alpha := 1.0
				if age > gs.solid_time:
					alpha = 1.0 - (age - gs.solid_time) / gs.fade_time
				alpha = clamp(alpha, 0.0, 1.0)
				draw_line(seg.start, seg.end, Color(seg.color, alpha), seg.width)
