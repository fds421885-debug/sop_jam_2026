extends Area2D

@export var speed := 600.0
var direction := Vector2.RIGHT

func _process(delta):
	position += direction * -speed * delta

func _on_body_entered(body):
	if body.name == "player":
		get_tree().reload_current_scene()
