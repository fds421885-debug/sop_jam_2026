extends Area2D

# نفس الإشارة التي ينتظرها الـ GameManager
signal player_caught

@export var speed: float = 350.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var is_exploding: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")


func _physics_process(delta: float) -> void:
	# تتحرك القذيفة للأمام طالما لم تنفجر بعد
	if not is_exploding:
		position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if is_exploding:
		return

	# إذا لمست اللاعب
	if body.is_in_group("player"):
		player_caught.emit()
		_explode()
	# إذا لمست جدار أو أرضية (أي جسم صلب آخر ليس مدفعاً أو قذيفة أخرى)
	elif not body.is_in_group("bullet") and not body.is_in_group("cannon"):
		_explode()


func _explode() -> void:
	is_exploding = true
	
	# تعطيل التصادم فوراً حتى لا تتكرر الضربة أثناء الانفجار
	$CollisionShape2D.set_deferred("disabled", true)
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("explode"):
		anim.play("explode")
		await anim.animation_finished  # ننتظر حتى ينتهي أنميشن الانفجار
	
	queue_free()  # حذف القذيفة من اللعبة
