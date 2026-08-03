extends CanvasLayer # أو CanvasLayer حسب النود الرئيسية عندك

## ============================================================
## سكربت واجهة Game Over
## ============================================================

@export_category("Transition")
@export var scene_transition: CanvasLayer # اسحب نود الانتقال هنا من المفتش (Inspector)

@export_category("Scenes")
@export_file("*.tscn") var play_scene: String   # مشهد إعادة اللعب
@export_file("*.tscn") var exit_scene: String   # مشهد القائمة الرئيسية

@export_category("Buttons")
@export var play_button: BaseButton
@export var exit_button: BaseButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	$"../AudioStreamPlayer".play()
	$"../AudioStreamPlayer2".play()

func _on_play_pressed() -> void:
	if not get_tree():
		return
		
	get_tree().paused = false
	
	if not play_scene.is_empty():
		_change_scene(play_scene)


func _on_exit_pressed() -> void:
	if not get_tree():
		return
		
	get_tree().paused = false
	
	if not exit_scene.is_empty():
		_change_scene(exit_scene)
	else:
		get_tree().quit()


# دالة مركزية للتحويل بين المشاهد
func _change_scene(target_path: String) -> void:
	# إذا كود الانتقال حقك فيه دالة معينة (مثلاً change_scene أو fade_to)، استدعيها
	if scene_transition and scene_transition.has_method("change_scene"):
		scene_transition.change_scene(target_path)
	else:
		# إذا المتغير فاضي أو ما فيه الدالة، يغير المشهد بالطريقة العادية
		get_tree().change_scene_to_file(target_path)
