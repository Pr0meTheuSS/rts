extends StaticBody3D

@export var to_follow: Node3D
@export var size: float

func _physics_process(delta: float) -> void:
	global_position.x = int(to_follow.global_position.x / size) * size
	global_position.z = int(to_follow.global_position.z / size) * size
