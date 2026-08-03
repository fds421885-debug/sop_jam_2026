extends Node2D

@export var bullet_scene: PackedScene    # اسحب مشهد Bullet.tscn هنا في المحرر
@export var shoot_interval: float = 2.0   # الوقت بالثواني بين كل طلقة وطلقة
@export var invert_direction: bool = false # 👈 فعّل هذا الخيار من الـ Inspector إذا كانت الطلقة تطلع بالعكس!

@onready var muzzle: Marker2D = $Muzzle
@onready var timer: Timer = $Timer
@onready var cannon_sprite: AnimatedSprite2D = $CannonSprite
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash


func _ready() -> void:
	# إخفاء تأثير الإطلاق في بداية اللعبة
	muzzle_flash.hide()
	
	# ربط إشارات انتهاء الأنميشن
	cannon_sprite.animation_finished.connect(_on_cannon_animation_finished)
	muzzle_flash.animation_finished.connect(_on_flash_animation_finished)
	
	# إعداد المؤقت
	timer.wait_time = shoot_interval
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	
	# تشغيل وضع السكون للمدفع
	if cannon_sprite.sprite_frames and cannon_sprite.sprite_frames.has_animation("idle"):
		cannon_sprite.play("idle")


func _on_timer_timeout() -> void:
	_shoot()


func _shoot() -> void:
	# 1. تشغيل أنميشن إطلاق المدفع
	if cannon_sprite.sprite_frames and cannon_sprite.sprite_frames.has_animation("shoot"):
		cannon_sprite.play("shoot")

	# 2. إظهار وتشغيل أنميشن تأثير الفوهة (Muzzle Flash)
	if muzzle_flash.sprite_frames and muzzle_flash.sprite_frames.has_animation("flash"):
		muzzle_flash.show()
		muzzle_flash.play("flash")

	# 3. إطلاق القذيفة
	if bullet_scene:
		var bullet = bullet_scene.instantiate() as Area2D
		bullet.global_position = muzzle.global_position
		
		# تحديد اتجاه الحركة (ومعالجته إذا كان معكوساً)
		var dir: Vector2 = muzzle.global_transform.x
		if invert_direction:
			dir = -dir

		bullet.direction = dir
		bullet.rotation = dir.angle()  # تدوير الطلقة تلقائياً لتواجه اتجاه انطلاقها

		get_tree().current_scene.add_child(bullet)

		# ربط القذيفة بـ GameManager تلقائياً
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager and game_manager.has_method("_on_player_caught"):
			bullet.player_caught.connect(game_manager._on_player_caught.bind(bullet))


func _on_cannon_animation_finished() -> void:
	# العودة لوضع السكون بعد الإطلاق
	if cannon_sprite.animation == "shoot":
		if cannon_sprite.sprite_frames and cannon_sprite.sprite_frames.has_animation("idle"):
			cannon_sprite.play("idle")


func _on_flash_animation_finished() -> void:
	# إخفاء تأثير الإطلاق فور انتهاء أنميشن الفلاش
	muzzle_flash.hide()
