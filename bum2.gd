extends Node2D

@export var bullet_scene: PackedScene

@onready var fire_point: Marker2D = $FirePoint

func _ready():
	$Timer.timeout.connect(_on_area_2d_body_shape_entered)



func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = fire_point.global_position
	bullet.rotation = global_rotation
	bullet.direction = Vector2.RIGHT.rotated(global_rotation)
