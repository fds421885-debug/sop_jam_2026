extends Area2D

# متغير ينشئ لك خانة اختيار الملف مباشرة من الـ Inspector
@export_file("*.tscn") var target_level: String

@export var animated_sprite: AnimatedSprite2D

func _on_body_entered(body: Node2D) -> void:
	# نتحقق إن اللي لمس الباب هو اللاعب (عن طريق المجموعة)
	if body.is_in_group("player"):
		# تشغيل انميشن الفتح
		animated_sprite.play("open")
		
		# ننتظر لين يخلص انميشن الفتح عشان يكون النقل رهيب
		await animated_sprite.animation_finished
		
		# إذا تم تحديد ليفل في الـ Inspector، يتم النقل له
		if target_level != "":
			get_tree().change_scene_to_file(target_level)
