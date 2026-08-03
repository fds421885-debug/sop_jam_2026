extends CanvasLayer

## ============================================================
## سكربت واجهة Game Over (مع حماية get_tree)
## ============================================================

@export_category("Scenes")
@export_file("*.tscn") var play_scene: String   # مشهد إعادة اللعب
@export_file("*.tscn") var exit_scene: String   # مشهد القائمة الرئيسية

@export_category("Buttons")
@export var play_button: BaseButton
@export var exit_button: BaseButton


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	$AudioStreamPlayer2.play()
	$AudioStreamPlayer.play()

func _on_play_pressed():
	if get_tree():
		get_tree().paused = false
		if play_scene:
			get_tree().change_scene_to_file("res://scence/test_fixed.tscn")
		else:
			get_tree().change_scene_to_file("res://scence/test_fixed.tscn")


func _on_exit_pressed():
	if get_tree():
		get_tree().paused = false
		if exit_scene:
			get_tree().change_scene_to_file(exit_scene)
		else:
			get_tree().quit()
