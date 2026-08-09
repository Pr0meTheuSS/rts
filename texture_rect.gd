extends TextureRect

@export var vehicle : Vehicle

const MIN_SPEED := 0.0
const MAX_SPEED := 220.0

const MIN_ANGLE := -124.0
const MAX_ANGLE := 124.0

func _process(_delta):
	var speed_kmh = vehicle.speed * 3.6
	var speed_mph = speed_kmh * 0.621371
	
	# ограничиваем диапазон
	speed_mph = clamp(speed_mph, MIN_SPEED, MAX_SPEED)
	
	# нормализуем (0 → 1)
	var t = speed_mph / MAX_SPEED
	
	# считаем угол
	var angle = lerp(MIN_ANGLE, MAX_ANGLE, t)
	
	# применяем (в радианах!)
	rotation = deg_to_rad(angle)
