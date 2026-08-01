@tool
extends Area2D
class_name AbilityZone

## ============================================================
## منطقة فرض قدرة (Ability Zone)
## ------------------------------------------------------------
## أي لاعب يدخل هذه المنطقة، وطالما بقي داخلها، ستكون القدرة التي
## "تخرج" من الروليت (سواء الآن أو أي روليت تالٍ يحدث وهو لا يزال بداخلها)
## هي القدرة المحددة هنا دائماً — القدرة تُحدَّد يدوياً من المبرمج/المصمم.
##
## طريقة الاستخدام في المحرر:
## 1) أضف عقدة Area2D جديدة واستخدم هذا السكريبت لها (أو اسحب المشهد الجاهز إن وُجد)
## 2) أضف CollisionShape2D كابن لها وحدد شكل/حجم المنطقة كما تريد
## 3) اختر forced_ability من القائمة المنسدلة في الـ Inspector
## 4) تأكد أن Collision Mask الخاص بالمنطقة يشمل الطبقة الفيزيائية للاعب
##    (نفس فكرة CharacterBody2D الخاص باللاعب) حتى تُكتشف الأجسام بشكل صحيح
##
## لا حاجة لأي تعديل إضافي في سكريبت اللاعب — الدوال المطلوبة
## (register_ability_zone / unregister_ability_zone) موجودة بالفعل فيه.
## ============================================================

## القدرة التي يجب أن تظهر دائماً طالما اللاعب داخل هذه المنطقة
@export_enum("double_jump", "glide", "dash", "wall_slide", "shock_wave", "slow_mo")
var forced_ability: String = "double_jump"

## false (افتراضي): القدرة تُفرض فقط عند حدوث الروليت التالي بشكل طبيعي
## (أي بعد انتهاء عداد القدرة الحالية) — لا يوجد تبديل مفاجئ لحظة الدخول
## true: القدرة تُفرض فوراً لحظة دخول اللاعب المنطقة، متجاوزةً الروليت بالكامل
@export var apply_immediately: bool = false

## لون تقريبي لعرض حدود المنطقة داخل المحرر فقط (لا يظهر إطلاقاً أثناء اللعب الفعلي)
@export var editor_debug_color: Color = Color(0.2, 0.8, 1.0, 0.25)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	# تحديث بسيط للرسم التقريبي داخل المحرر فقط، لا يعمل أثناء التشغيل الفعلي
	if Engine.is_editor_hint():
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	# فحص بسيط: أي جسم يملك الدوال المطلوبة (أي سكريبت اللاعب) يُعتبر لاعباً
	if body.has_method("register_ability_zone"):
		body.register_ability_zone(self, forced_ability, apply_immediately)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("unregister_ability_zone"):
		body.unregister_ability_zone(self)


## رسم تقريبي لحدود المنطقة واسم القدرة المفروضة — للمساعدة أثناء التصميم فقط
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			var extents := size / 2.0
			draw_rect(Rect2(child.position - extents, size), editor_debug_color, true)
			draw_string(
				ThemeDB.fallback_font,
				child.position + Vector2(-extents.x, -extents.y - 8),
				"AbilityZone: " + forced_ability,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14
			)
