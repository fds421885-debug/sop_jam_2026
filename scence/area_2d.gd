extends Area2D

@onready var gameover: CanvasLayer = $"../gameover"



func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		gameover.visible = true
		get_tree().paused = true
		$"../AudioStreamPlayer2".play()
