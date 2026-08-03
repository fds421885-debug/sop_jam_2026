extends Area2D

@export_file("*.tscn") var target_level: String
@export var animated_sprite: AnimatedSprite2D
@export var win_screen: CanvasLayer # 👈 اسحب نود الكانفاس لاير هنا (لو ما سحبته بينتقل للمرحلة مباشرة)

var is_won: bool = false


func _ready() -> void:
	# إخفاء شاشة الفوز في بداية اللعبة لو كانت موجودة
	if win_screen:
		win_screen.hide()
		
	# التأكد من ربط إشارة دخول الجسم
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# نمنع تكرار الفوز أكثر من مرة
	if is_won:
		return

	# نتحقق إن اللي لمس الباب هو اللاعب
	if body.is_in_group("player"):
		is_won = true
		
		# تشغيل أنميشن الفتح إذا كان موجوداً
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("open"):
			animated_sprite.play("open")
			await animated_sprite.animation_finished

		# إذا فيه شاشة فوز نعرضها، وإذا ما فيه ننقل اللاعب للمرحلة التالية مباشرة
		if win_screen:
			_show_win_screen_animated()
		elif target_level != "":
			get_tree().change_scene_to_file(target_level)


func _show_win_screen_animated() -> void:
	if not win_screen:
		return

	win_screen.show()

	# نأخذ أول عنصر UI داخل الـ CanvasLayer لتكبيره (مثل Panel أو Control)
	var anim_target: Node = win_screen
	if win_screen.get_child_count() > 0:
		anim_target = win_screen.get_child(0)

	if "scale" in anim_target:
		# ضبط نقطة المرتكز (Pivot) في نص العنصر بالضبط عشان التكبير يبدأ من المنتصف
		if "pivot_offset" in anim_target and "size" in anim_target:
			anim_target.pivot_offset = anim_target.size / 2.0

		anim_target.scale = Vector2.ZERO

		# إنشاء التوين مع تفعيل الاشتغال حتى واللعبة متوقفة
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(anim_target, "scale", Vector2.ONE, 0.45)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

	# إيقاف حركة اللعبة بعد الانبثاق
	if get_tree():
		get_tree().paused = true
