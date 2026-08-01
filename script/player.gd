@tool
extends CharacterBody2D

## ============================================================
## سكريبت لاعب متقدم — حركة + نظام قدرات دوّار يعتمد على
## "إدراك بيئي" حقيقي (Raycasts + تحليل التهديدات) بدل العشوائية الساذجة
## ============================================================
##
## متطلبات الإعداد قبل التشغيل:
## 1) ضع كل الأعداء ضمن المجموعة (Group) باسم "enemy"
## 2) (اختياري) ضع المخاطر مثل الأشواك/الحمم ضمن مجموعة "hazard"
## 3) اضبط environment_scan_mask على طبقات الأرض/الجدران الفعلية في مشروعك
## 4) current_ability ما زال من نوع String (وليس enum) عمداً حتى يبقى
##    متوافقاً مع أي كود آخر في مشروعك (AI Game Forge) يقرأ هذه القيمة
## 5) لفرض قدرة معينة داخل منطقة محددة بالمستوى، أضف عقدة تستخدم سكريبت
##    AbilityZone.gd (مرفق في ملف منفصل) — لا حاجة لأي كود إضافي في اللاعب
## 6) للأنيميشن: اختر عقدة AnimatedSprite2D من حقل Animated Sprite Path في
##    مجموعة Animation — بعدها ستتحول حقول الأنيميشن تلقائياً لقوائم منسدلة
##    تعرض أسماء الأنيميشنز الموجودة فعلياً داخل SpriteFrames الخاص بتلك العقدة
##    (يتطلب Godot 4.3+)

# -------------------- الحركة الأساسية --------------------
@export_group("Movement")
@export var speed: float = 300.0
@export var jump_velocity: float = -450.0
@export var coyote_time: float = 0.12       # مهلة سماح للقفز بعد مغادرة الأرض
@export var jump_buffer_time: float = 0.12  # تخزين ضغطة القفز قبل لمس الأرض

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# -------------------- إعدادات القدرات --------------------
@export_group("Abilities Tuning")
@export var double_jump_boost_multiplier: float = 0.2
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.15
@export var wall_slide_gravity_factor: float = 0.1
@export var glide_gravity_factor: float = 0.3
@export var slow_mo_factor: float = 0.4

@export_group("Abilities Timers")
@export var time_double_jump: float = 15.0
@export var time_glide: float = 12.0
@export var time_dash: float = 10.0
@export var time_wall_slide: float = 15.0
@export var time_shock_wave: float = 10.0
@export var time_slow_mo: float = 8.0
@export var random_selection_duration: float = 3.0

@export_group("Ability Selection Feel")
## بدل تجميد اللاعب بالكامل أثناء عرض الروليت، تتباطأ الحركة والجاذبية بهذه
## النسبة (1.0 = بلا تأثير أي حركة طبيعية، كل ما اقتربت من 0 كل ما كانت أبطأ)
@export_range(0.01, 1.0) var selection_slowmo_factor: float = 0.2

# -------------------- نظام الإدراك البيئي (Environment Sensing) --------------------
@export_group("Environment Sensing")
@export var enemy_detection_radius: float = 350.0
@export var pit_check_distance: float = 60.0    # مسافة أفقية أمام اللاعب لفحص الهوة
@export var pit_check_depth: float = 160.0      # طول الشعاع نحو الأسفل
@export var ceiling_check_length: float = 60.0
@export var wall_check_length: float = 40.0
@export var fall_speed_danger_threshold: float = 700.0
@export var height_fall_danger_threshold: float = 200.0
@export var hazard_detection_radius: float = 250.0
@export_flags_2d_physics var environment_scan_mask: int = 1

@export_group("Smart Weight Multipliers")
@export var w_enemy_shock_wave: float = 6.0
@export var w_enemy_dash: float = 3.0
@export var w_enemy_slow_mo: float = 4.0
@export var w_enemy_surrounded_shock_wave: float = 5.0
@export var w_wall_slide_on_wall: float = 8.0
@export var w_airborne_double_jump: float = 4.0
@export var w_airborne_glide: float = 4.0
@export var w_pit_glide: float = 6.0
@export var w_pit_double_jump: float = 4.0
@export var w_pit_dash: float = 5.0
@export var w_low_ceiling_penalty: float = 5.0
@export var w_fast_fall_glide: float = 7.0
@export var w_fast_fall_wall_slide: float = 4.0
@export var w_hazard_shock_wave: float = 5.0
@export var w_hazard_dash: float = 4.0
@export var w_narrow_space_wall_slide: float = 3.0
@export var repetition_penalty_per_recent_use: float = 2.5
@export var ability_history_size: int = 3

@export_group("Forced Double Jump Override")
## إذا وُجد عائق/حافة أعلى من مدى القفزة العادية لكنه ضمن مدى القفزة المزدوجة،
## يتم منح قدرة القفزة المزدوجة فوراً — حتى لو كانت هذه القدرة نفسها مستخدمة قبل قليل
@export var forced_jump_cooldown_duration: float = 0.25

# -------------------- إعدادات الأنيميشن --------------------
@export_group("Animation")
## اختر عقدة AnimatedSprite2D — بمجرد اختيارها ستظهر أسماء أنيميشناتها
## كقوائم منسدلة في الحقول الستة أدناه بدل الكتابة اليدوية
@export var animated_sprite_path: NodePath:
	set(value):
		animated_sprite_path = value
		notify_property_list_changed()

@export var anim_idle: String = ""
@export var anim_run: String = ""
@export var anim_jump: String = ""
@export var anim_fall: String = ""
@export var anim_land: String = ""   ## تأكد من إطفاء خانة Loop له في الـ SpriteFrames Editor
@export var anim_death: String = ""

const _ANIM_FIELDS := ["anim_idle", "anim_run", "anim_jump", "anim_fall", "anim_land", "anim_death"]

# -------------------- تعريف القدرات (تبقى نصوص للتوافق) --------------------
const ABILITY_DOUBLE_JUMP := "double_jump"
const ABILITY_GLIDE := "glide"
const ABILITY_DASH := "dash"
const ABILITY_WALL_SLIDE := "wall_slide"
const ABILITY_SHOCK_WAVE := "shock_wave"
const ABILITY_SLOW_MO := "slow_mo"

var all_abilities: Array[String] = [
	ABILITY_DOUBLE_JUMP, ABILITY_GLIDE, ABILITY_DASH,
	ABILITY_WALL_SLIDE, ABILITY_SHOCK_WAVE, ABILITY_SLOW_MO,
]

const ABILITY_DISPLAY_NAMES := {
	ABILITY_DOUBLE_JUMP: "قفزة مزدوجة",
	ABILITY_GLIDE: "انزلاق هوائي",
	ABILITY_DASH: "داش سريع [Shift]",
	ABILITY_WALL_SLIDE: "التصاق جداري",
	ABILITY_SHOCK_WAVE: "درع الحماية المحيط [زر E]",
	ABILITY_SLOW_MO: "تباطؤ الزمن [زر Q]",
}

# -------------------- حالة اللعبة --------------------
var current_ability: String = ABILITY_DOUBLE_JUMP
var ability_timer: float = 0.0
var max_ability_time: float = 15.0
var ability_history: Array[String] = []  # لعقوبة تكرار القدرات المستخدمة مؤخراً

var can_double_jump: bool = true
var is_gliding: bool = false
var is_dashing: bool = false
var is_slow_mo_active: bool = false
var last_facing_dir: float = 1.0
var is_selecting_random: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var time_since_grounded: float = 0.0
var _emitted_critical_warning: bool = false
var _forced_jump_cooldown: float = 0.0
var _sequence_id: int = 0  # يُستخدم لإلغاء تسلسل الروليت إن حدثت قفزة إجبارية عاجلة
var _active_ability_zones: Array = []  # مكدس مناطق فرض القدرات التي يقف اللاعب داخلها حالياً

# -------------------- حالة الأنيميشن --------------------
var _was_on_floor: bool = true
var _is_landing: bool = false
var _is_dead: bool = false

# -------------------- إشارات (لفصل الواجهة/الصوت عن منطق اللعبة) --------------------
signal ability_changed(new_ability)
signal ability_timer_critical

# -------------------- مسارات الواجهة --------------------
@onready var instability_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var ability_label: Label = $CanvasLayer/Control/AbilityLabel
@onready var ability_icon: TextureRect = $CanvasLayer/Control/AbilityIcon
@onready var shockwave_area: Area2D = $ShockwaveArea
@onready var camera: Camera2D = $Camera2D
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null(animated_sprite_path)

@export var icon_double_jump: Texture2D
@export var icon_glide: Texture2D
@export var icon_dash: Texture2D
@export var icon_wall_slide: Texture2D
@export var icon_shock_wave: Texture2D
@export var icon_slow_mo: Texture2D

var ability_icons: Dictionary = {}


## ============================================================
##  دعم محرر Godot — توليد القوائم المنسدلة لأسماء الأنيميشن ديناميكياً
## ============================================================

## يُستدعى تلقائياً من المحرر لكل خاصية مُصدَّرة قبل عرضها في الـ Inspector.
## نستخدمه لتحويل حقول الأنيميشن الستة من نص حر إلى قائمة منسدلة (Enum)
## تعرض فقط الأسماء الموجودة فعلياً داخل SpriteFrames الخاص بالعقدة المختارة
func _validate_property(property: Dictionary) -> void:
	if property.name in _ANIM_FIELDS:
		var names := _get_available_animation_names()
		if names.size() > 0:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(names)
		else:
			# لا توجد عقدة/SpriteFrames مختارة بعد — يبقى كحقل نص عادي
			property.hint = PROPERTY_HINT_NONE
			property.hint_string = ""


## يجلب أسماء الأنيميشنز من SpriteFrames الخاص بالعقدة المحددة في animated_sprite_path
func _get_available_animation_names() -> PackedStringArray:
	if animated_sprite_path.is_empty():
		return PackedStringArray()

	var sprite := get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return PackedStringArray()

	return sprite.sprite_frames.get_animation_names()


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # لا تشغّل أي منطق لعب داخل المحرر — فقط دعم الـ Inspector أعلاه يعمل هناك

	animated_sprite = get_node_or_null(animated_sprite_path)

	ability_icons = {
		ABILITY_DOUBLE_JUMP: icon_double_jump,
		ABILITY_GLIDE: icon_glide,
		ABILITY_DASH: icon_dash,
		ABILITY_WALL_SLIDE: icon_wall_slide,
		ABILITY_SHOCK_WAVE: icon_shock_wave,
		ABILITY_SLOW_MO: icon_slow_mo,
	}

	if instability_bar:
		instability_bar.min_value = 0
		instability_bar.max_value = 100
		instability_bar.value = 100

	if shockwave_area:
		shockwave_area.monitoring = false
		shockwave_area.visible = false
		if not shockwave_area.body_entered.is_connected(_on_shockwave_body_entered):
			shockwave_area.body_entered.connect(_on_shockwave_body_entered)

	set_ability_timer_duration(current_ability)
	ability_timer = max_ability_time
	update_ui()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_animation()

	_forced_jump_cooldown = max(0.0, _forced_jump_cooldown - delta)

	# فحص عاجل: هل هناك عائق عالٍ لا يمكن الوصول إليه إلا بقفزة مزدوجة؟
	# هذا الفحص يعمل حتى أثناء تسلسل الروليت، ويتجاوز عداد الوقت وعقوبة التكرار بالكامل
	if _forced_jump_cooldown <= 0.0 and current_ability != ABILITY_DOUBLE_JUMP:
		if _check_high_obstacle_needs_double_jump():
			force_grant_double_jump_ability()

	if is_selecting_random:
		_process_selection_slowmo(delta)
		return

	_update_timers(delta)

	var time_modifier: float = slow_mo_factor if is_slow_mo_active else 1.0
	ability_timer -= delta * time_modifier

	if ability_timer <= 3.0 and not _emitted_critical_warning:
		_emitted_critical_warning = true
		ability_timer_critical.emit()
	elif ability_timer > 3.0:
		_emitted_critical_warning = false

	if ability_timer <= 0:
		start_random_ability_sequence()
		return

	update_ui()
	_handle_ability_toggles()

	if is_dashing:
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		last_facing_dir = direction

	_apply_gravity(delta)
	_handle_jump_input()

	if current_ability == ABILITY_SHOCK_WAVE and Input.is_key_pressed(KEY_E):
		activate_shock_wave()

	_apply_horizontal_movement(direction)

	move_and_slide()


func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		time_since_grounded = 0.0
		can_double_jump = true
		is_gliding = false
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		time_since_grounded += delta

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta


func _handle_ability_toggles() -> void:
	if current_ability == ABILITY_SLOW_MO:
		if Input.is_action_just_pressed("slow_mo") or Input.is_key_pressed(KEY_Q):
			is_slow_mo_active = !is_slow_mo_active

	if current_ability == ABILITY_DASH and not is_dashing:
		if Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_SHIFT):
			start_hollow_knight_dash()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var current_gravity := gravity
	if is_slow_mo_active:
		current_gravity *= slow_mo_factor  # تعديل الجاذبية نفسها بدل ضرب السرعة كل فريم (كان يسبب سقوط خاطئ تراكمي)

	if is_gliding:
		current_gravity *= glide_gravity_factor
	elif current_ability == ABILITY_WALL_SLIDE and is_on_wall() and velocity.y > 0:
		current_gravity *= wall_slide_gravity_factor

	velocity.y += current_gravity * delta


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		$AudioStreamPlayer.play()
	if jump_buffer_timer <= 0:
		return

	if is_on_floor() or coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif current_ability != ABILITY_DASH and current_ability != ABILITY_WALL_SLIDE:
		handle_air_abilities()
		jump_buffer_timer = 0.0


func _apply_horizontal_movement(direction: float) -> void:
	var current_speed: float = speed * (slow_mo_factor if is_slow_mo_active else 1.0)
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)


## يُستدعى بدل التجميد الكامل أثناء عرض الروليت (is_selecting_random) — بدل ما
## يتوقف اللاعب فجأة، تستمر الجاذبية والحركة الأفقية بالعمل لكن بتباطؤ زمني
## حقيقي (لا حركة بصرية وهمية) بحيث يبدو المشهد سينمائياً بدل التجميد المفاجئ
func _process_selection_slowmo(delta: float) -> void:
	var slow_delta := delta * selection_slowmo_factor

	if not is_on_floor():
		velocity.y += gravity * slow_delta
	else:
		velocity.y = 0.0

	var direction := Input.get_axis("ui_left", "ui_right")
	var slow_speed: float = speed * selection_slowmo_factor
	if direction:
		velocity.x = direction * slow_speed
	else:
		velocity.x = move_toward(velocity.x, 0, slow_speed)

	move_and_slide()


func set_ability_timer_duration(ab_name: String) -> void:
	match ab_name:
		ABILITY_DOUBLE_JUMP: max_ability_time = time_double_jump
		ABILITY_GLIDE: max_ability_time = time_glide
		ABILITY_DASH: max_ability_time = time_dash
		ABILITY_WALL_SLIDE: max_ability_time = time_wall_slide
		ABILITY_SHOCK_WAVE: max_ability_time = time_shock_wave
		ABILITY_SLOW_MO: max_ability_time = time_slow_mo
		_: max_ability_time = 15.0


func handle_air_abilities() -> void:
	if current_ability == ABILITY_DOUBLE_JUMP and can_double_jump:
		var boosted_jump: float = jump_velocity * (1.0 + double_jump_boost_multiplier)
		if is_slow_mo_active:
			boosted_jump *= slow_mo_factor
		velocity.y = boosted_jump
		can_double_jump = false
	elif current_ability == ABILITY_GLIDE:
		is_gliding = true


func start_hollow_knight_dash() -> void:
	is_dashing = true
	is_gliding = false

	var dash_dir := last_facing_dir
	if Input.is_action_pressed("ui_left"):
		dash_dir = -1.0
	elif Input.is_action_pressed("ui_right"):
		dash_dir = 1.0

	last_facing_dir = dash_dir
	var current_dash_speed: float = dash_speed * (slow_mo_factor if is_slow_mo_active else 1.0)
	velocity.x = current_dash_speed * dash_dir
	velocity.y = 0

	var timer_wait: float = dash_duration / (slow_mo_factor if is_slow_mo_active else 1.0)
	await get_tree().create_timer(timer_wait).timeout
	is_dashing = false


func activate_shock_wave() -> void:
	if shockwave_area and shockwave_area.monitoring:
		return

	if shockwave_area:
		shockwave_area.position = Vector2.ZERO
		shockwave_area.monitoring = true
		shockwave_area.visible = true

		var timer_wait: float = 0.3 / (slow_mo_factor if is_slow_mo_active else 1.0)
		await get_tree().create_timer(timer_wait).timeout

		if shockwave_area:
			shockwave_area.monitoring = false
			shockwave_area.visible = false


func _on_shockwave_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.has_method("die"):
		body.queue_free()


# ============================================================
#  نظام الإدراك البيئي — القلب الجديد لاختيار القدرات
# ============================================================

## يطلق شعاعاً فيزيائياً بسيطاً ويستثني جسم اللاعب نفسه
func _raycast(from: Vector2, to: Vector2) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = environment_scan_mask
	return space_state.intersect_ray(query)


## يحسب أقصى ارتفاع (بالبيكسل) تصل إليه قفزة عادية واحدة، من معادلة الحركة v²/2g
func _get_single_jump_height() -> float:
	return (jump_velocity * jump_velocity) / (2.0 * gravity)


## يحسب الارتفاع الإضافي الذي تضيفه القفزة المزدوجة فوق القفزة العادية
func _get_double_jump_extra_height() -> float:
	var boosted_velocity: float = jump_velocity * (1.0 + double_jump_boost_multiplier)
	return (boosted_velocity * boosted_velocity) / (2.0 * gravity)


## يكتشف وجود عائق/حافة أمام اللاعب أعلى من مدى القفزة العادية، لكنه ضمن
## مدى القفزة المزدوجة — أي "شيء عالٍ اللاعب ما يقدر يوصلّو" بدون قفزة مزدوجة
func _check_high_obstacle_needs_double_jump() -> bool:
	var single_h := _get_single_jump_height()
	var double_h := single_h + _get_double_jump_extra_height()

	var forward := Vector2(last_facing_dir, 0)
	var probe_origin := global_position + forward * wall_check_length

	# هل يوجد عائق يمتد حتى قرب أقصى ارتفاع القفزة العادية؟ (لا يمكن تخطيه بقفزة واحدة)
	var low_probe_hit := _raycast(probe_origin, probe_origin + Vector2(0, -single_h * 0.9))
	if low_probe_hit.is_empty():
		return false  # لا يوجد عائق بهذا الارتفاع أصلاً، لا داعي للتدخل

	# هل قمة هذا العائق تقع ضمن مدى القفزة المزدوجة (أي قابل للتخطي)؟
	var high_probe_hit := _raycast(probe_origin, probe_origin + Vector2(0, -double_h))
	return high_probe_hit.is_empty()


## نواة مشتركة: تبدّل القدرة الحالية فوراً لأي قدرة محددة، متجاوزةً عداد الوقت،
## عقوبة التكرار، وأي تسلسل روليت جارٍ — تُستخدم من قفزة الطوارئ ومناطق فرض القدرات
func _force_switch_to_ability(ability_name: String, shake_duration: float = 0.25, shake_intensity: float = 10.0) -> void:
	if not all_abilities.has(ability_name):
		return

	_sequence_id += 1  # يُلغي أي تسلسل روليت قيد التنفيذ حالياً (راجع start_random_ability_sequence)
	is_selecting_random = false

	ability_history.push_front(current_ability)
	if ability_history.size() > ability_history_size:
		ability_history.pop_back()

	current_ability = ability_name
	set_ability_timer_duration(current_ability)
	ability_timer = max_ability_time
	_emitted_critical_warning = false
	_forced_jump_cooldown = forced_jump_cooldown_duration

	is_gliding = false
	is_dashing = false
	is_slow_mo_active = false
	can_double_jump = true  # ضمان إمكانية استخدام القفزة الإضافية فوراً دون انتظار الهبوط

	ability_changed.emit(current_ability)
	shake_camera(shake_duration, shake_intensity)
	update_ui()


## يمنح اللاعب قدرة القفزة المزدوجة فوراً عند اكتشاف عائق عالٍ عاجل (راجع _check_high_obstacle_needs_double_jump)
func force_grant_double_jump_ability() -> void:
	_force_switch_to_ability(ABILITY_DOUBLE_JUMP, 0.25, 10.0)


# ============================================================
#  مناطق فرض القدرات (Ability Zones) — تُستدعى تلقائياً من AbilityZone.gd
# ============================================================

## يسجّل دخول اللاعب إلى منطقة تفرض قدرة معينة
func register_ability_zone(zone: Node, ability_name: String, apply_immediately: bool) -> void:
	unregister_ability_zone(zone)  # احتياطي لمنع تسجيل نفس المنطقة مرتين
	_active_ability_zones.append({"zone": zone, "ability": ability_name})

	if apply_immediately and current_ability != ability_name:
		_force_switch_to_ability(ability_name)


## يلغي تسجيل اللاعب عند خروجه من المنطقة
func unregister_ability_zone(zone: Node) -> void:
	for i in range(_active_ability_zones.size() - 1, -1, -1):
		if _active_ability_zones[i]["zone"] == zone:
			_active_ability_zones.remove_at(i)


## يعيد القدرة المفروضة من آخر منطقة دخلها اللاعب (الأحدث دخولاً تفوز)، أو نص فارغ إن لم توجد أي منطقة
func _get_zone_forced_ability() -> String:
	if _active_ability_zones.is_empty():
		return ""
	return _active_ability_zones[_active_ability_zones.size() - 1]["ability"]


## يبني "لقطة" كاملة عن حالة البيئة المحيطة باللاعب في هذه اللحظة
func scan_environment() -> Dictionary:
	var env := {}

	# --- 1) تحليل الأعداء المحيطين: العدد، أقرب مسافة، وهل اللاعب محاصر من الجهتين ---
	var enemies := get_tree().get_nodes_in_group("enemy")
	var closest_dist := INF
	var enemies_in_range := 0
	var enemy_left := false
	var enemy_right := false
	for enemy in enemies:
		if enemy is Node2D:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < enemy_detection_radius:
				enemies_in_range += 1
				closest_dist = min(closest_dist, dist)
				if enemy.global_position.x < global_position.x:
					enemy_left = true
				else:
					enemy_right = true
	env["enemies_nearby"] = enemies_in_range
	env["closest_enemy_dist"] = closest_dist
	env["surrounded_by_enemies"] = enemy_left and enemy_right

	# --- 2) مخاطر بيئية (أشواك/حمم/فخاخ...) عبر مجموعة "hazard" ---
	var hazard_near := false
	for hazard in get_tree().get_nodes_in_group("hazard"):
		if hazard is Node2D and global_position.distance_to(hazard.global_position) < hazard_detection_radius:
			hazard_near = true
			break
	env["hazard_nearby"] = hazard_near

	# --- 3) حالة الأرض/الجدران الأساسية ---
	env["is_airborne"] = not is_on_floor()
	env["on_wall"] = is_on_wall()
	env["fall_speed"] = velocity.y
	env["time_since_grounded"] = time_since_grounded

	# --- 4) جدار أمام اللاعب مقابل خلفه (باتجاه النظر) ---
	var forward := Vector2(last_facing_dir, 0)
	var wall_ahead_hit := _raycast(global_position, global_position + forward * wall_check_length)
	var wall_behind_hit := _raycast(global_position, global_position - forward * wall_check_length)
	env["facing_wall_ahead"] = not wall_ahead_hit.is_empty()
	env["wall_behind"] = not wall_behind_hit.is_empty()
	env["narrow_space"] = env["facing_wall_ahead"] and env["wall_behind"]

	# --- 5) هل توجد هوة/فراغ أمام اللاعب؟ (فحص بالشعاع نحو الأسفل أمامه) ---
	var pit_origin := global_position + forward * pit_check_distance
	var pit_hit := _raycast(pit_origin, pit_origin + Vector2(0, pit_check_depth))
	env["pit_ahead"] = pit_hit.is_empty()

	# --- 6) سقف منخفض فوق اللاعب (يقلل فائدة القفزة المزدوجة) ---
	var ceiling_hit := _raycast(global_position, global_position + Vector2(0, -ceiling_check_length))
	env["low_ceiling"] = not ceiling_hit.is_empty()

	# --- 7) الارتفاع الفعلي عن أقرب أرضية أسفل اللاعب ---
	var probe_depth := height_fall_danger_threshold * 2.0
	var ground_hit := _raycast(global_position, global_position + Vector2(0, probe_depth))
	if ground_hit.is_empty():
		env["height_above_ground"] = probe_depth
	else:
		env["height_above_ground"] = global_position.distance_to(ground_hit["position"])

	env["falling_dangerously"] = (
		env["fall_speed"] > fall_speed_danger_threshold
		and env["height_above_ground"] > height_fall_danger_threshold
	)

	return env


## يحوّل لقطة البيئة إلى أوزان لكل قدرة — كل شرط بيئي يرفع/يخفض وزن القدرات المناسبة له
func get_smart_ability_weights(env: Dictionary) -> Dictionary:
	var weights := {}
	for ab in all_abilities:
		weights[ab] = 1.0

	# منع اختيار القدرة الحالية نفسها مرة أخرى مباشرة
	weights[current_ability] = 0.0

	# عقوبة التكرار: أي قدرة استُخدمت مؤخراً يقل وزنها تدريجياً حسب حداثة استخدامها
	# بدلاً من استبعاد القدرة الحالية فقط، هذا يمنع تكرار نفس 2-3 قدرات بشكل مزعج
	for i in range(ability_history.size()):
		var recent_ability: String = ability_history[i]
		var recency_factor: float = float(ability_history.size() - i) / float(ability_history.size())
		var penalty: float = repetition_penalty_per_recent_use * recency_factor
		weights[recent_ability] = max(0.0, weights.get(recent_ability, 1.0) - penalty)

	# 1) وجود أعداء قريبين
	if env["enemies_nearby"] > 0:
		weights[ABILITY_SHOCK_WAVE] += w_enemy_shock_wave
		weights[ABILITY_DASH] += w_enemy_dash
		weights[ABILITY_SLOW_MO] += w_enemy_slow_mo
		if env["surrounded_by_enemies"]:
			weights[ABILITY_SHOCK_WAVE] += w_enemy_surrounded_shock_wave

	# 2) ملامسة جدار حالياً
	if env["on_wall"]:
		weights[ABILITY_WALL_SLIDE] += w_wall_slide_on_wall

	# 3) اللاعب في الهواء
	if env["is_airborne"]:
		weights[ABILITY_DOUBLE_JUMP] += w_airborne_double_jump
		weights[ABILITY_GLIDE] += w_airborne_glide

	# 4) هوة/فراغ أمام اللاعب — القدرات التي تساعد على العبور أو الطيران فوقها
	if env["pit_ahead"]:
		weights[ABILITY_GLIDE] += w_pit_glide
		weights[ABILITY_DOUBLE_JUMP] += w_pit_double_jump
		weights[ABILITY_DASH] += w_pit_dash

	# 5) سقف منخفض — القفزة المزدوجة أقل فائدة (قد تصطدم بالسقف)
	if env["low_ceiling"]:
		weights[ABILITY_DOUBLE_JUMP] = max(0.2, weights[ABILITY_DOUBLE_JUMP] - w_low_ceiling_penalty)

	# 6) سقوط سريع وخطير من ارتفاع كبير
	if env["falling_dangerously"]:
		weights[ABILITY_GLIDE] += w_fast_fall_glide
		weights[ABILITY_WALL_SLIDE] += w_fast_fall_wall_slide

	# 7) وجود خطر بيئي قريب (أشواك/حمم)
	if env["hazard_nearby"]:
		weights[ABILITY_SHOCK_WAVE] += w_hazard_shock_wave
		weights[ABILITY_DASH] += w_hazard_dash

	# 8) مساحة ضيقة بين جدارين
	if env["narrow_space"]:
		weights[ABILITY_WALL_SLIDE] += w_narrow_space_wall_slide

	return weights


## يختار القدرة التالية — يعطي الأولوية لمنطقة فرض القدرة إن كان اللاعب واقفاً
## داخلها، وإلا يعتمد على مسح البيئة الفعلي + الأوزان الذكية كالمعتاد
func select_contextual_ability() -> String:
	var zone_forced := _get_zone_forced_ability()
	if zone_forced != "" and all_abilities.has(zone_forced):
		return zone_forced

	var env := scan_environment()
	var weights := get_smart_ability_weights(env)

	var total_weight := 0.0
	for ab in weights:
		total_weight += weights[ab]

	if total_weight <= 0.0:
		var available: Array[String] = []
		for ab in all_abilities:
			if ab != current_ability:
				available.append(ab)
		return available[randi() % available.size()]

	var random_val := randf() * total_weight
	var current_sum := 0.0
	for ab in weights:
		current_sum += weights[ab]
		if random_val <= current_sum:
			return ab

	return ABILITY_DOUBLE_JUMP


func start_random_ability_sequence() -> void:
	_sequence_id += 1
	var my_sequence_id := _sequence_id

	is_selecting_random = true
	is_slow_mo_active = false
	is_gliding = false

	if ability_label:
		ability_label.text = "جاري إعادة ضبط الجينات..."

	var step_time := random_selection_duration / 6.0
	for i in range(6):
		# لو حدثت قفزة إجبارية عاجلة أثناء الروليت، نلغي هذا التسلسل فوراً
		if my_sequence_id != _sequence_id:
			return
		if ability_icon:
			var random_preview: String = all_abilities[randi() % all_abilities.size()]
			ability_icon.texture = ability_icons.get(random_preview)
		await get_tree().create_timer(step_time).timeout

	if my_sequence_id != _sequence_id:
		return

	# الاختيار النهائي يعتمد على مسح البيئة الحقيقي وليس عشوائية بحتة
	var chosen_ability := select_contextual_ability()
	select_new_ability(chosen_ability)


func select_new_ability(new_ability_name: String) -> void:
	is_selecting_random = false

	ability_history.push_front(current_ability)
	if ability_history.size() > ability_history_size:
		ability_history.pop_back()

	current_ability = new_ability_name
	set_ability_timer_duration(current_ability)
	ability_timer = max_ability_time
	_emitted_critical_warning = false

	is_gliding = false
	is_dashing = false
	is_slow_mo_active = false

	ability_changed.emit(new_ability_name)
	shake_camera(0.4, 15.0)
	update_ui()


func shake_camera(duration: float, intensity: float) -> void:
	if not camera:
		return

	var original_offset := camera.offset
	var elapsed_time := 0.0

	while elapsed_time < duration:
		if not camera:
			break
		camera.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		elapsed_time += get_process_delta_time()
		await get_tree().process_frame

	if camera:
		camera.offset = original_offset


func update_ui() -> void:
	if is_selecting_random:
		return

	if instability_bar:
		var progress_percent: float = (ability_timer / max_ability_time) * 100.0
		instability_bar.value = progress_percent
		instability_bar.modulate = Color(1, 0, 0) if ability_timer <= 3.0 else Color(1, 1, 1)

	if ability_label:
		var name_text: String = ABILITY_DISPLAY_NAMES.get(current_ability, current_ability)
		if current_ability == ABILITY_SLOW_MO and is_slow_mo_active:
			name_text += " (نشط)"
		ability_label.text = name_text + " | باقي: " + str(int(ability_timer)) + "ث"

	if ability_icon:
		ability_icon.texture = ability_icons.get(current_ability)


# ============================================================
#  نظام الأنيميشن — يعتمد فقط على حالة الحركة الفعلية للاعب
# ============================================================

func _update_animation() -> void:
	if not animated_sprite or _is_dead:
		return

	# فليب الأنيميشن حسب اتجاه النظر
	if last_facing_dir != 0:
		animated_sprite.flip_h = last_facing_dir < 0

	# اكتشاف لحظة الهبوط: انتقال من هواء → أرض
	if is_on_floor() and not _was_on_floor:
		_play_land_animation()
	_was_on_floor = is_on_floor()

	if _is_landing:
		return  # ننتظر انتهاء أنيميشن الهبوط قبل أي تبديل آخر

	if not is_on_floor():
		_play_animation(anim_jump if velocity.y < 0 else anim_fall)
	else:
		var moving: bool = abs(velocity.x) > 10.0
		_play_animation(anim_run if moving else anim_idle)


func _play_animation(anim_name: String) -> void:
	if anim_name == "" or not animated_sprite or not animated_sprite.sprite_frames:
		return
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return  # تجاهل بصمت لو الاسم غير موجود بدل ما يكسر اللعبة
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)


func _play_land_animation() -> void:
	if anim_land == "" or not animated_sprite or not animated_sprite.sprite_frames:
		return
	if not animated_sprite.sprite_frames.has_animation(anim_land):
		return
	_is_landing = true
	animated_sprite.play(anim_land)
	if not animated_sprite.animation_finished.is_connected(_on_land_animation_finished):
		animated_sprite.animation_finished.connect(_on_land_animation_finished, CONNECT_ONE_SHOT)


func _on_land_animation_finished() -> void:
	_is_landing = false


## نادِ هذه الدالة من أي مكان (عدو، فخ، سقوط قاتل...) لتشغيل أنيميشن الموت
func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	set_physics_process(false)
	if animated_sprite:
		_play_animation(anim_death)
