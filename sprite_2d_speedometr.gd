#extends TextureRect
#
#func _ready():
	#update_size()
#
#func _notification(what):
	#if what == NOTIFICATION_RESIZED:
		#update_size()
#
#func update_size():
	#var screen_size = get_viewport_rect().size
	#
	## 5% от ширины экрана
	#var target_size = screen_size.x * 0.25
	#WAAAAAAAAA
	#var texture_size = texture.get_size()
	#var scale_factor = target_size / texture_size.x
	#
	#scale = Vector2(scale_factor, scale_factor)
