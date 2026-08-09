extends Node3D

@export var slowdown: float = 0.1
@export var sound_volume: float = 0.05
@export var sound_speed: float = 2

const TIME_STOP = preload("uid://dh3pxo4vxxvyg")
const TIME_CONTINUE = preload("uid://bpcn1kvofv6fl")

var audio_stream_player: AudioStreamPlayer

func _ready() -> void:
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	audio_stream_player.volume_linear = sound_volume

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_speed"):
		if Engine.time_scale == 1.0:
			Engine.time_scale = slowdown
			audio_stream_player.stream = TIME_STOP
		else:
			Engine.time_scale = 1.0
			audio_stream_player.stream = TIME_CONTINUE
		audio_stream_player.play()
