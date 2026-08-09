class_name GraphSeries
extends RefCounted

var x_source_key: String = ""
var y_source_key: String = ""
var color := Color.WHITE
var size := 4.0
var trail_width := 2.0
var solid_time := 0.5
var fade_time := 1.0
var trail_mode := 0

# Для 2D монитора
var _prev_plot_pos := Vector2.INF
var trail_segments: Array = []

# Для 1D монитора (история точек с временными метками)
var history: Array = []   # [{x: float, y: float, time: float}]

# Эмиттер (создаётся монитором)
var particles: GPUParticles2D = null

func from_dict(d: Dictionary) -> void:
	x_source_key = d.get("x_key", x_source_key)
	y_source_key = d.get("y_key", y_source_key)
	color = d.get("color", color)
	size = d.get("size", size)
	trail_width = d.get("trail_width", trail_width)
	solid_time = d.get("solid_time", solid_time)
	fade_time = d.get("fade_time", fade_time)
	trail_mode = d.get("trail_mode", trail_mode)
