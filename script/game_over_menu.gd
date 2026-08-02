extends Control

@export_category("Scenes")
@export_file("*.tscn") var play_scene: String   # مشهد إعادة اللعب
@export_file("*.tscn") var exit_scene: String   # مشهد الخروج (أو اتركه فاضي عشان يقفل اللعبة)

@export_category("Buttons")
# استخدمنا BaseButton عشان تدعم الزر العادي (Button) و الـ (TextureButton)
@export var play_button: BaseButton
@export var exit_button: BaseButton

func _ready():

	# إظهار الماوس عشان اللاعب يقدر يضغط
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# ربط الأزرار بالكود تلقائياً
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

func _on_play_pressed():
	if play_scene:
		get_tree().change_scene_to_file(play_scene)
	else:
		# لو ما حددت مشهد، يعيد تحميل المرحلة الحالية افتراضياً
		get_tree().reload_current_scene()

func _on_exit_pressed():
	if exit_scene:
		get_tree().change_scene_to_file(exit_scene)
	else:
		# لو ما حددت مشهد خروج، بيقفل اللعبة نهائياً
		get_tree().quit()
