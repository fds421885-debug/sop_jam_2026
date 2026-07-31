extends Panel


@onready var instability_bar: ProgressBar = $Control/ProgressBar
@onready var ability_label: Label = $Control/Label

# اربط هذا السكريبت بـ Node اللاعب أو استقبل الإشارات
func _ready() -> void:
	# مثال: افترضنا أن اللاعب موجود في المشهد بهذا المسار
	var player = get_node("../Player")
	if player:
		player.connect("ability_used", Callable(self, "_on_player_ability_used"))
		player.connect("critical_point_reached", Callable(self, "_on_critical_point"))

func _on_player_ability_used(instability: float, level: int) -> void:
	instability_bar.value = instability
	ability_label.text = "القدرة مستوى: " + str(level) + " | عدم الاستقرار: " + str(instability) + "%"
	
	# تغيير لون العداد حسب النسبة (أخضر -> أصفر -> برتقالي -> أحمر)
	var fill_style = instability_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if instability < 50:
			fill_style.bg_color = Color.WEB_GREEN
		elif instability < 75:
			fill_style.bg_color = Color.YELLOW
		elif instability < 100:
			fill_style.bg_color = Color.ORANGE_RED
		else:
			fill_style.bg_color = Color.RED

func _on_critical_point() -> void:
	print("💥 CRITICAL POINT UI ACTIVATED!")
	# هنا بنظهر شاشة اختيار القدرات الجديدة (Dash, Grappling Hook, Glide)
