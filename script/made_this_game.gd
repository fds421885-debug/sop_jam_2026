extends Node

# تصدير العقد للفاحص (الانسبكتور) - 3 خانات فقط!
@export var credits_canvas: CanvasLayer
@export var open_button: Button
@export var close_button: TextureButton

# إعدادات السرعة والمسافة
@export var anim_duration: float = 0.35  # سرعة الحركة بالثواني
@export var slide_offset: float = 150.0  # مسافة الصعود والهبوط بالبكسل

var default_offset: Vector2 = Vector2.ZERO
var tween: Tween

func _ready():
	if credits_canvas:
		default_offset = credits_canvas.offset # حفظ الموضع الأصلي للكانفاس
		credits_canvas.hide()
		
	if open_button:
		open_button.show()
		open_button.pressed.connect(_on_open_pressed)
		
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

# عند الضغط على زر ! (تحريك الكانفاس كاملاً للأعلى + Fade In)
func _on_open_pressed():
	if not credits_canvas: return
	
	if tween and tween.is_running(): tween.kill()
	
	if open_button: open_button.hide()
	credits_canvas.show()
	
	# إزاحة الكانفاس كاملاً للأسفل كبداية للحركة
	credits_canvas.offset = default_offset + Vector2(0, slide_offset)
	
	tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# تحريك offset الكانفاس كاملاً إلى موقعه الأصلي
	tween.tween_property(credits_canvas, "offset", default_offset, anim_duration)
	
	# تطبيق الشفافية تلقائياً على المحتوى الداخلي للكانفاس
	if credits_canvas.get_child_count() > 0 and credits_canvas.get_child(0) is Control:
		var main_child = credits_canvas.get_child(0)
		main_child.modulate.a = 0.0
		tween.tween_property(main_child, "modulate:a", 1.0, anim_duration)

# عند الضغط على زر X (تحريك الكانفاس كاملاً لأسفل + Fade Out)
func _on_close_pressed():
	if not credits_canvas: return
	
	if tween and tween.is_running(): tween.kill()
	
	var target_offset = default_offset + Vector2(0, slide_offset)
	
	tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# إزاحة الكانفاس لأسفل
	tween.tween_property(credits_canvas, "offset", target_offset, anim_duration)
	
	# إخفاء الشفافية تدريجياً
	if credits_canvas.get_child_count() > 0 and credits_canvas.get_child(0) is Control:
		var main_child = credits_canvas.get_child(0)
		tween.tween_property(main_child, "modulate:a", 0.0, anim_duration)
	
	await tween.finished
	credits_canvas.hide()
	if open_button: open_button.show()
