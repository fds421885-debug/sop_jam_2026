extends Node

## ============================================================
## GameManager بسيط — للاختبار السريع فقط
## ============================================================
## ضعه كعقدة Node منفصلة بجذر المشهد، واسحب مرجع العدو (أو أكثر من
## عدو) لمصفوفة enemies من الـ Inspector. يستمع لإشارة player_caught
## من كل عدو، ويطبع رسالة + يعيد ضبط اللاعب والعدو بعد تأخير بسيط،
## عشان تقدر تختبر المطاردة بشكل مستمر بدون ما "يعلق" أول لمسة.
##
## للإصدار النهائي من لعبتك: استبدل _on_player_caught بمنطق الـ Game
## Over الفعلي عندك (عرض UI، إيقاف اللعبة، تسجيل النقاط، إلخ)
## ============================================================

@export var enemies: Array[Node] = []          ## اسحب هنا كل عقد ChaserEnemy بالمشهد
@export var player: Node2D                      ## اسحب عقدة اللاعب
@export var player_spawn_position: Vector2       ## موقع بداية اللاعب لإعادة الضبط
@export var respawn_delay: float = 1.0           ## ثواني قبل إعادة الضبط بعد اللمس


func _ready() -> void:
	for enemy in enemies:
		if enemy and enemy.has_signal("player_caught"):
			enemy.player_caught.connect(_on_player_caught.bind(enemy))


func _on_player_caught(enemy: Node) -> void:
	print("[GameManager] تم الإمساك باللاعب! Game Over مؤقت — سيُعاد الضبط بعد ", respawn_delay, " ثانية")

	# ---- هنا مكان منطق الـ Game Over الحقيقي عندك ----
	# مثال: $UI/GameOverScreen.show()
	# مثال: get_tree().paused = true
	# ---------------------------------------------------

	await get_tree().create_timer(respawn_delay).timeout
	_respawn(enemy)


func _respawn(enemy: Node) -> void:
	if player and player_spawn_position != Vector2.ZERO:
		player.global_position = player_spawn_position
		if player.has_method("reset_state"):
			player.reset_state()

	if enemy and enemy.has_method("reset_state"):
		enemy.reset_state()

	print("[GameManager] تمت إعادة الضبط — المطاردة تبدأ من جديد")
