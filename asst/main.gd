extends Control

@onready var BOX: VBoxContainer = $VBoxContainer

@onready var panel: Panel = $Panel
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2

func _on_button_pressed() -> void:
	$AudioStreamPlayer2.play()
	get_tree().change_scene_to_file("res://level.tscn")


func _ready() -> void:
	panel.visible = false
	BOX.visible = true

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
