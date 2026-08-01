extends Control

@export var BOX: VBoxContainer

@export var panel: Panel 
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2

func _on_button_pressed() -> void:
	$AudioStreamPlayer2.play()
	get_tree().change_scene_to_file("res://level.tscn")


func _ready() -> void:
	panel.visible = false
	BOX.visible = true
	$CanvasLayer/Parallax2D/AnimatedSprite2D2.play("palm")
	$CanvasLayer/Parallax2D/AnimatedSprite2D3.play("palm")
	$CanvasLayer/Parallax2D/AnimatedSprite2D4.play("default")
	$CanvasLayer/Parallax2D/AnimatedSprite2D5.play("default")
	$CanvasLayer/Parallax2D/AnimatedSprite2D.play("default")
	$CanvasLayer/AnimationPlayer.play("cloud")
func _on_button_2_pressed() -> void:
	$AudioStreamPlayer2.play()
	print("stinng")
	BOX	.visible = false
	panel.visible = true
	

func _on_button_3_pressed() -> void:
	$AudioStreamPlayer2.play()
	get_tree().quit()




func _on_button_4_pressed() -> void:
	_ready()
