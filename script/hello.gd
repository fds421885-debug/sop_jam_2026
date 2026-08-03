extends CanvasLayer

## ============================================================
## TutorialManager - نظام شريحة التعليمات والحفظ المباشر
## ============================================================

@export_category("Tutorial Slides")
@export var slides: Array[CanvasLayer] = [] # 👈 حط الشرائح الـ 3 هنا بالترتيب

@export_category("Navigation Buttons")
@export var next_button: BaseButton # 👈 زر التقدم (TextureButton أو Button)
@export var prev_button: BaseButton # 👈 زر الرجوع
@export var done_button: BaseButton # 👈 زر "تم" للإنهاء

# مسار ملف الحفظ في جهاز اللاعب
const SAVE_PATH: String = "user://tutorial_settings.cfg"

var current_slide_index: int = 0


func _ready() -> void:
	# 1. التحقق أولاً: هل شاهد اللاعب التعليمات سابقاً؟
	if _is_tutorial_completed():
		_close_and_disable_tutorial()
		return

	# 2. ربط إشارات الأزرار
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if done_button:
		done_button.pressed.connect(_on_done_pressed)

	# 3. عرض الشريحة الأولى وتحديث وضع الأزرار
	_update_slides_and_buttons()


func _update_slides_and_buttons() -> void:
	# إخفاء جميع الشرائح ما عدا الشريحة الحالية
	for i in range(slides.size()):
		if slides[i]:
			if i == current_slide_index:
				slides[i].show()
			else:
				slides[i].hide()

	var total_slides: int = slides.size()

	# الشريحة الأخيرة: يختفي زرا التنقل ويظهر زر "تم"
	if current_slide_index == total_slides - 1:
		if next_button: next_button.hide()
		if prev_button: prev_button.hide()
		if done_button: done_button.show()

	# الشريحة الأولى: يظهر زر التالي ويختفي الرجوع وزر "تم"
	elif current_slide_index == 0:
		if next_button: next_button.show()
		if prev_button: prev_button.hide()
		if done_button: done_button.hide()

	# الشرائح الوسطى: يظهر زرا التالي والرجوع ويختفي زر "تم"
	else:
		if next_button: next_button.show()
		if prev_button: prev_button.show()
		if done_button: done_button.hide()


func _on_next_pressed() -> void:
	if current_slide_index < slides.size() - 1:
		current_slide_index += 1
		_update_slides_and_buttons()


func _on_prev_pressed() -> void:
	if current_slide_index > 0:
		current_slide_index -= 1
		_update_slides_and_buttons()


func _on_done_pressed() -> void:
	# حفظ حالة الإتمام بملف دائيم
	_save_tutorial_completed()
	# إخفاء وحذف نظام التعليمات من اللعبة
	_close_and_disable_tutorial()


func _save_tutorial_completed() -> void:
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", true)
	config.save(SAVE_PATH)


func _is_tutorial_completed() -> bool:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		return config.get_value("tutorial", "completed", false)
	return false


func _close_and_disable_tutorial() -> void:
	# إخفاء كل العناصر
	for slide in slides:
		if slide:
			slide.hide()

	if next_button: next_button.hide()
	if prev_button: prev_button.hide()
	if done_button: done_button.hide()

	# حذف النود نهائياً من شجرة المشهد
	queue_free()
