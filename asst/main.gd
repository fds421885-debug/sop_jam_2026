extends Control

@onready var BOX: VBoxContainer = $VBoxContainer

@onready var panel: Panel = $Panel

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scence/level_1.tscn")
	


func _ready() -> void:
	panel.visible = false
	BOX.visible = true

func _on_button_2_pressed() -> void:
	print("stinng")
	BOX	.visible = false
	panel.visible = true
	

func _on_button_3_pressed() -> void:
	get_tree().quit()




func _on_button_4_pressed() -> void:
	_ready()
