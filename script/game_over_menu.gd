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
func _on_play_pressed():
	get_tree().change_scene_to_file("res://scence/test_fixed.tscn")
