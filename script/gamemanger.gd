extends Node

## ============================================================
## GameManager (مع حماية get_tree ودعم الحوايا/Containers)
## ============================================================

@export_category("Enemies & Player")
@export var enemies: Array[Node] = []          
@export var enemy_containers: Array[Node] = []  # حط هنا النود الأب اللي يجمع الأشواك أو الأعداء
@export var player: Node2D                      
@export var player_spawn_position: Vector2       
@export var respawn_delay: float = 1.0           

@export_category("UI & Game Over")
@export var game_over_screen: Node              


func _ready() -> void:
	if get_tree():
		get_tree().paused = false

	if game_over_screen:
		game_over_screen.hide()

	# تجميع الأعداء المنفردين + جميع أطفال الحوايا (Containers)
	var all_enemies: Array[Node] = enemies.duplicate()
	
	for container in enemy_containers:
		if container:
			for child in container.get_children():
				all_enemies.append(child)

	# ربط الإشارات لكل الأعداء
	for enemy in all_enemies:
		if enemy and enemy.has_signal("player_caught"):
			if not enemy.player_caught.is_connected(_on_player_caught):
				enemy.player_caught.connect(_on_player_caught.bind(enemy))


func _on_player_caught(enemy: Node) -> void:
	print("[GameManager] تم الإمساك باللاعب! Game Over")

	_show_game_over_animated()

	if get_tree():
		get_tree().paused = true


func _show_game_over_animated() -> void:
	if not game_over_screen:
		return

	game_over_screen.show()

	var anim_target: Node = game_over_screen
	if not ("scale" in anim_target) and anim_target.get_child_count() > 0:
		anim_target = anim_target.get_child(0)

	if "scale" in anim_target:
		if "pivot_offset" in anim_target and "size" in anim_target:
			anim_target.pivot_offset = anim_target.size / 2.0

		anim_target.scale = Vector2.ZERO

		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(anim_target, "scale", Vector2.ONE, 0.45)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)


func _respawn(enemy: Node) -> void:
	if player and player_spawn_position != Vector2.ZERO:
		player.global_position = player_spawn_position
		if player.has_method("reset_state"):
			player.reset_state()

	if enemy and enemy.has_method("reset_state"):
		enemy.reset_state()

	print("[GameManager] تمت إعادة الضبط — المطاردة تبدأ من جديد")
