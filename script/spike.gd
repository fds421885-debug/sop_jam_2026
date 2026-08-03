extends Area2D

# نفس الإشارة اللي ينتظرها الـ GameManager
signal player_caught

func _ready() -> void:
	# نربط إشارة اصطدام جسم بالمنطقة
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# نتحقق هل الجسم اللي دخل هو اللاعب؟
	if body.is_in_group("player"):
		player_caught.emit()
