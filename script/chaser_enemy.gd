@tool
class_name ChaserEnemy
extends CharacterBody2D

## ============================================================
## عدو مطارد (Chaser Enemy) — منصات 2D — نظام "تتبع المسار" (Trail Following)
## ============================================================
## الفكرة: العدو ما يحلل العالم حوله إطلاقاً (بدون رايكاست، بدون قرار
## قفز يدوي). بدل ذلك، يسجّل مسار اللاعب لحظة بلحظة، ثم يمشي على نفس
## النقاط بالضبط بعد تأخير بسيط — كأن فيه خط خلف اللاعب والعدو يمشي
## عليه حرفياً. بما إن اللاعب هو من نفّذ القفزة/الحركة فعلياً، إعادة
## تشغيل نفس المسار تعني أن العدو يقفز/يتفادى نفس العوائق تلقائياً
## بدون أي منطق تصادم إضافي — مضمون 100% أنه مسار صالح.
##
## عشان ما تصير مطاردة "بمسافة ثابتة للأبد" (لو اللاعب يجري بسرعة
## منتظمة)، فيه "معدل لحاق" (catch_up_rate) يخلي الفجوة الزمنية بين
## العدو والمسار المسجّل تتقلّص تدريجياً، فيحس اللاعب إن العدو "يقرب"
## فعلياً مع الوقت، مو بس يمشي وراه بنفس المسافة.
##
## ملاحظة عن الجاذبية: المحور الأفقي (X) يتبع المسار المسجَّل كما هو،
## أما المحور الرأسي (Y) فصار يعتمد على جاذبية حقيقية + قفزة تُطلَق
## تلقائياً كل ما كانت النقطة الهدف على المسار أعلى من العدو وهو واقف
## على أرض — فيتحرك العدو مثل أي شخصية منصات عادية بدل "التحليق"
## المباشر نحو نقطة المسار.
##
## إعداد المشهد المطلوب:
## 1) ضع اللاعب ضمن المجموعة "player" حتى يجده العدو تلقائياً بلا إعداد يدوي
## 2) (اختياري) أضف Area2D باسم CatchArea مع CollisionShape2D → catch_area_path
##    (مصدر إضافي وموثوق لاكتشاف "اللمس" الفعلي، بجانب فحص catch_distance)
## 3) (اختياري) عقدة AnimatedSprite2D بأنيميشن "run" فقط
##    → animated_sprite_path (يتحول حقل anim_run أدناه لقائمة منسدلة
##    تلقائياً — يتطلب Godot 4.3+). العدو يشغّل أنيميشن الركض دوماً
##    ولا يستخدم idle/jump/fall/catch بعد الآن.
##    (اختياري) عقدة Node2D تحوي السبرايت فقط لعكسه بالكامل بدل flip_h → facing_pivot_path
## 4) (اختياري) ثلاث عقد AudioStreamPlayer2D لأصوات الخطى/الهبوط/الزئير
##
## ملاحظة: لا حاجة لأي رايكاست أو ضبط أبعاد عوائق يدوياً بعد الآن —
## هذا كله أُلغي، العدو يعتمد فقط على مسار اللاعب المسجَّل + جاذبية حقيقية.

# ============================================================
#  تتبع المسار (المحرّك الأساسي للمطاردة)
# ============================================================
@export_group("Trail Following")
@export var max_follow_speed: float = 650.0
## سقف السرعة الأفقية اللحظية (px/s) — يمنع "قفزة" مفاجئة لو تراكمت فجوة كبيرة
## دفعة وحدة (مثلاً بعد إعادة ضبط، أو أول تشغيل)
@export var facing_deadzone_px: float = 4.0
## أقل فرق أفقي (بيكسل) يُعتبر سبباً كافياً لعكس اتجاه الوجهة — يمنع
## اهتزاز السبرايت لو الفرق دقيق جداً
@export var stop_deceleration: float = 2000.0
## معدل تباطؤ السرعة الأفقية عند تعطيل المطاردة (chase_enabled = false)

# ============================================================
#  الجاذبية والقفز
# ============================================================
@export_group("Physics")
@export var gravity: float = 980.0
## قوة الجاذبية (px/s²) المطبَّقة على العدو عندما لا يكون على الأرض
@export var max_fall_speed: float = 1200.0
## سقف سرعة السقوط الرأسي
@export var jump_impulse: float = 420.0
## سرعة القفزة الرأسية (px/s) التي تُطلَق تلقائياً عندما تكون نقطة
## المسار الهدف أعلى من العدو وهو واقف على الأرض
@export var jump_trigger_height: float = 12.0
## أقل فرق ارتفاع (بيكسل) بين العدو ونقطة المسار الهدف يُعتبر سبباً كافياً للقفز
@export var max_jumps: int = 2
## أقصى عدد قفزات متتالية بالهواء (2 = قفزة عادية + دبل جمب) — يطابق قدرة
## اللاعب على الدبل جمب حتى يقدر العدو يوصل لأماكن ما توصلها إلا بدبل جمب
@export var jump_cooldown: float = 0.18
## أقل فاصل زمني بين قفزتين متتاليتين للعدو (يمنع تنفيذ كل قفزات الدبل جمب دفعة وحدة بفريم واحد)

# ============================================================
#  الإنقاذ التلقائي (Stuck / Fell Recovery)
# ============================================================
## بإضافة الجاذبية والفيزياء الحقيقية، صار ممكن العدو "يعلق" بجدار أو
## "يطيح" بفجوة عبرها اللاعب بدبل جمب ولا يقدر العدو يوصلها بقفزاته
## العادية. هذا النظام يراقب الحالتين ويرجّع العدو تلقائياً لآخر نقطة
## "مضمونة وصالحة" من مسار اللاعب المسجَّل نفسه (نقطة وقف عليها اللاعب
## فعلياً) — فيحافظ على نفس ضمان "مسار صالح 100%" من التصميم الأصلي.
@export_group("Stuck Recovery")
@export var recovery_enabled: bool = true
@export var stuck_time_threshold: float = 0.6
## كم ثانية يُعتبر العدو "عالق" (ملاصق حائط ومحتاج يتحرك ولا يقدر) قبل الإنقاذ
@export var fell_into_gap_threshold: float = 180.0
## أقصى فرق ارتفاع (بيكسل) يُسمح للعدو يكون تحت نقطة المسار الهدف قبل
## اعتباره "طاح بحفرة ما يقدر يطلع منها" وتفعيل الإنقاذ

# ============================================================
#  اكتشاف اللمس = Game Over
# ============================================================
@export_group("Catch Detection")
@export var catch_distance: float = 20.0        # خط دفاع ثانٍ لاكتشاف "اللمس" بجانب CatchArea

# ============================================================
#  نظام الصعوبة
# ============================================================
@export_group("Difficulty")
@export_range(1, 4) var start_difficulty_level: int = 1

## جدول ثابت لكل مستوى صعوبة:
## trail_delay  = كم ثانية "يتأخر" العدو خلف اللاعب على نفس المسار (أقل = أصعب)
## catch_up_rate = مدى سرعة تقلّص الفجوة الزمنية مع الوقت (>1.0 يعني
##                 العدو يقرأ المسار أسرع من إنتاجه، فيقرب تدريجياً حتى
##                 لو اللاعب يجري بسرعة ثابتة للأبد؛ 1.0 = فجوة ثابتة أبدية)
const DIFFICULTY_TABLE := {
	1: {"trail_delay": 1.20, "catch_up_rate": 1.02},
	2: {"trail_delay": 0.90, "catch_up_rate": 1.08},
	3: {"trail_delay": 0.60, "catch_up_rate": 1.18},
	4: {"trail_delay": 0.35, "catch_up_rate": 1.35},
}

var difficulty_level: int = 1
var _trail_delay: float = 1.0
var _catch_up_rate: float = 1.02

# ============================================================
#  مراجع العقد (تُضبط من الـ Inspector)
# ============================================================
@export_group("Node References")
@export var animated_sprite_path: NodePath:
	set(value):
		animated_sprite_path = value
		notify_property_list_changed()
@export var facing_pivot_path: NodePath   ## اختياري — عقدة Node2D تحوي السبرايت فقط، تُعكس أفقياً بالكامل (بديل عن flip_h)
@export var catch_area_path: NodePath
@export var footstep_audio_path: NodePath
@export var land_audio_path: NodePath
@export var growl_audio_path: NodePath

# ============================================================
#  الأنيميشن (أنيميشن الركض فقط — قائمة منسدلة تلقائية)
# ============================================================
@export_group("Animation")
@export var anim_run: String = ""
## أنيميشن الركض هو الوحيد المستخدَم حالياً؛ يُشغَّل باستمرار طالما
## السبرايت موجود واسم الأنيميشن صالح — بلا حالات idle/jump/fall/catch منفصلة

const _ANIM_FIELDS := ["anim_run"]

# ============================================================
#  الصوت
# ============================================================
@export_group("Audio")
@export var enable_footsteps: bool = true
@export var footstep_interval: float = 0.35
@export var growl_interval_min: float = 3.0
@export var growl_interval_max: float = 7.0

# ============================================================
#  التحكم أثناء التشغيل
# ============================================================
@export_group("Runtime Control")
@export var chase_enabled: bool = true   ## أوقفها من الكود قبل بدء اللعبة أو بعد Game Over

# ============================================================
#  التصحيح (Debug)
# ============================================================
@export_group("Debug")
@export var debug_draw: bool = false
@export var debug_log: bool = true   ## يطبع رسائل بالـ Output توضح حالة إيجاد اللاعب والإمساك

# -------------------- حالات اللعبة (State Machine) --------------------
enum State { IDLE, RUN, JUMP, FALL, CATCH }
var current_state: State = State.IDLE

# -------------------- إشارات --------------------
signal player_caught                       ## يُلتقط من GameManager لعرض Game Over
signal difficulty_changed(new_level: int)
signal state_changed(new_state: int)

# -------------------- حالة داخلية --------------------
var player: Node2D = null
var facing_direction: float = 1.0

var _footstep_timer: float = 0.0
var _growl_timer: float = 0.0
var _player_search_timer: float = 0.0   ## يعيد محاولة إيجاد اللاعب دورياً لو ما لقاه بالبداية

# -------------------- قفز (يشمل دبل جمب) + إنقاذ تلقائي --------------------
var _jumps_used: int = 0
var _jump_cooldown_timer: float = 0.0
var _was_on_floor: bool = true
var _stuck_timer: float = 0.0
var _current_target_point: Vector2 = Vector2.ZERO
var _current_target_valid: bool = false

# -------------------- شريط تسجيل مسار اللاعب --------------------
# مصفوفة نقاط مسجَّلة (نقطة واحدة كل فريم فيزيائي)، مع فهرسة عامة (لا
# تُصفَّر عند التقليم) عشان نقدر نحسب "فجوة التأخير" بدقة بالنقاط
var _trail: Array = []                  ## Array[Vector2]
var _trail_start_index: int = 0         ## الفهرس العام لأول عنصر موجود فعلياً بـ _trail
var _write_index: int = 0               ## آخر فهرس عام تمت كتابته (يزيد ١ كل تسجيل)
var _read_cursor: float = 0.0           ## موقع "رأس القراءة" الحالي (فهرس عائم) على الشريط
const _TRIM_MARGIN: int = 8             ## هامش أمان قبل حذف نقاط قديمة من المصفوفة

@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null(animated_sprite_path)
@onready var _facing_pivot: Node2D = get_node_or_null(facing_pivot_path)
@onready var _catch_area: Area2D = get_node_or_null(catch_area_path)
@onready var _footstep_player: AudioStreamPlayer2D = get_node_or_null(footstep_audio_path)
@onready var _land_player: AudioStreamPlayer2D = get_node_or_null(land_audio_path)
@onready var _growl_player: AudioStreamPlayer2D = get_node_or_null(growl_audio_path)


## ============================================================
##  دعم محرر Godot — قائمة أنيميشن الركض المنسدلة
## ============================================================
func _validate_property(property: Dictionary) -> void:
	if property.name in _ANIM_FIELDS:
		_apply_enum_hint(property, _get_animation_names())


func _apply_enum_hint(property: Dictionary, names: PackedStringArray) -> void:
	if names.size() > 0:
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(names)
	else:
		property.hint = PROPERTY_HINT_NONE
		property.hint_string = ""


func _get_animation_names() -> PackedStringArray:
	if animated_sprite_path.is_empty():
		return PackedStringArray()
	var sprite := get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return PackedStringArray()
	return sprite.sprite_frames.get_animation_names()


# ============================================================
#  التهيئة
# ============================================================
func _ready() -> void:
	if Engine.is_editor_hint():
		return  # فقط دعم القائمة المنسدلة لأنيميشن الركض يعمل داخل المحرر

	_animated_sprite = get_node_or_null(animated_sprite_path)
	_facing_pivot = get_node_or_null(facing_pivot_path)
	_catch_area = get_node_or_null(catch_area_path)
	_footstep_player = get_node_or_null(footstep_audio_path)
	_land_player = get_node_or_null(land_audio_path)
	_growl_player = get_node_or_null(growl_audio_path)

	if _catch_area and not _catch_area.body_entered.is_connected(_on_catch_area_body_entered):
		_catch_area.body_entered.connect(_on_catch_area_body_entered)

	_find_player()
	_apply_difficulty(start_difficulty_level)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if debug_log:
		print("[ChaserEnemy] _find_player -> nodes in group 'player': ", players.size())
	if players.size() > 0:
		player = players[0]
		if debug_log:
			print("[ChaserEnemy] player found: ", player.name)
	else:
		player = null
		if debug_log:
			print("[ChaserEnemy] WARNING: no node in group 'player'. تأكد أن عقدة اللاعب منضمة لمجموعة اسمها 'player' بالضبط.")


# ============================================================
#  الحلقة الفيزيائية الرئيسية
# ============================================================
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if player == null:
		_player_search_timer -= delta
		if _player_search_timer <= 0.0:
			_find_player()
			_player_search_timer = 0.5

	if current_state == State.CATCH:
		return  # تم الإمساك باللاعب بالفعل — تجميد كامل، بانتظار GameManager

	_record_player_trail()

	# جاذبية حقيقية: تُطبَّق دائماً ما دام العدو ليس على الأرض، سواء كان
	# يلاحق المسار أو متوقفاً
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0
		if not _was_on_floor:
			_jumps_used = 0   # هبط على الأرض → صفّر رصيد القفزات (يشمل الدبل جمب)
	_was_on_floor = is_on_floor()

	if _jump_cooldown_timer > 0.0:
		_jump_cooldown_timer -= delta

	if chase_enabled and player != null:
		_follow_trail(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stop_deceleration * delta)
		_current_target_valid = false

	_check_catch_by_distance()

	move_and_slide()

	if chase_enabled:
		_update_recovery_watchdog(delta)

	_update_state()
	_update_animation()
	_update_footsteps(delta)
	_update_growl(delta)

	if debug_draw:
		queue_redraw()


# ============================================================
#  تسجيل مسار اللاعب — نقطة واحدة كل فريم فيزيائي
# ============================================================
func _record_player_trail() -> void:
	if player == null:
		return

	_trail.append(player.global_position)
	_write_index += 1

	# تقليم دوري: نحذف النقاط اللي فات عليها رأس القراءة فعلاً (+ هامش
	# أمان بسيط) عشان المصفوفة ما تكبر للأبد بجلسة لعب طويلة
	var consumable: int = int(_read_cursor) - _trail_start_index - _TRIM_MARGIN
	if consumable > 0 and consumable < _trail.size():
		_trail = _trail.slice(consumable, _trail.size())
		_trail_start_index += consumable


# ============================================================
#  اللحاق بالمسار المسجَّل (أفقياً) + جاذبية/قفز حقيقيين (رأسياً)
# ============================================================
func _follow_trail(delta: float) -> void:
	if _trail.is_empty():
		velocity.x = 0.0
		_current_target_valid = false
		return

	var target_lag_points: float = _trail_delay * float(Engine.physics_ticks_per_second)
	var target_read_index: float = float(_write_index) - target_lag_points

	if target_read_index <= float(_trail_start_index):
		# ما زال ما تراكم تاريخ كافٍ من حركة اللاعب — العدو ينتظر بمكانه
		# (هذا طبيعي أول ثانية من بداية المرحلة، أو بعد إعادة الضبط)
		velocity.x = 0.0
		_current_target_valid = false
		return

	# رأس القراءة يتقدّم بمعدل أسرع شوي من إنتاج نقاط جديدة (catch_up_rate)
	# عشان الفجوة الزمنية تتقلّص تدريجياً — إحساس "قاعد يقرب مني" حقيقي
	_read_cursor = min(_read_cursor + _catch_up_rate, target_read_index)
	_read_cursor = max(_read_cursor, float(_trail_start_index))

	var local_index: int = int(_read_cursor) - _trail_start_index
	local_index = clampi(local_index, 0, _trail.size() - 1)
	var target_point: Vector2 = _trail[local_index]
	_current_target_point = target_point
	_current_target_valid = true

	var to_target: Vector2 = target_point - global_position

	# أفقياً: يتحرك نحو النقطة الهدف بسرعة محدودة بسقف max_follow_speed
	if absf(to_target.x) > 1.0:
		velocity.x = clampf(to_target.x / delta, -max_follow_speed, max_follow_speed)
	else:
		velocity.x = 0.0

	# رأسياً: لا يُحلَّق نحو الهدف؛ بدل ذلك يقفز فقط لو كانت نقطة المسار
	# أعلى منه بفارق واضح — قفزة عادية وهو على الأرض، أو قفزة إضافية
	# بالهواء لو باقي رصيد (دبل جمب يطابق قدرة اللاعب) — والجاذبية
	# تتكفل بالباقي بدل "التحليق" المباشر نحو الهدف
	var wants_to_jump: bool = to_target.y < -jump_trigger_height and _jump_cooldown_timer <= 0.0
	if wants_to_jump:
		if is_on_floor():
			velocity.y = -jump_impulse
			_jumps_used = 1
			_jump_cooldown_timer = jump_cooldown
		elif _jumps_used < max_jumps:
			velocity.y = -jump_impulse
			_jumps_used += 1
			_jump_cooldown_timer = jump_cooldown

	if absf(to_target.x) > facing_deadzone_px:
		_apply_facing(sign(to_target.x))


func _apply_facing(direction: float) -> void:
	if direction == facing_direction:
		return
	facing_direction = direction
	if _facing_pivot:
		_facing_pivot.scale.x = abs(_facing_pivot.scale.x) * -direction
	elif _animated_sprite:
		_animated_sprite.flip_h = direction > 0.0


# ============================================================
#  الإنقاذ التلقائي (Stuck / Fell Recovery)
# ============================================================
## يراقب حالتين تكسران ضمان "الوصول دائماً" اللي كان موجود بالتصميم الأصلي:
## 1) عالق بجدار: يحاول يتحرك أفقياً بس مصدود بحائط لفترة طويلة
## 2) طاح تحت مستوى نقطة المسار الهدف بمسافة أكبر من يقدر يطلع منها
##    بقفزاته المتاحة (زي فجوة عبرها اللاعب بدبل جمب والعدو ما وصلها)
## بالحالتين نرجّعه فوراً لآخر نقطة "صالحة ومضمونة" من مسار اللاعب نفسه
## (نقطة وقف عليها اللاعب فعلياً) بدل ما يضل عالق/طايح للأبد.
func _update_recovery_watchdog(delta: float) -> void:
	if not recovery_enabled or not _current_target_valid:
		_stuck_timer = 0.0
		return

	var horizontal_gap: float = absf(_current_target_point.x - global_position.x)
	var vertical_gap: float = _current_target_point.y - global_position.y  # سالب = العدو تحت الهدف (طايح)

	var pressed_against_wall: bool = is_on_wall() and horizontal_gap > facing_deadzone_px and absf(velocity.x) < 5.0
	var fell_into_gap: bool = vertical_gap < -fell_into_gap_threshold

	if pressed_against_wall or fell_into_gap:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= stuck_time_threshold:
		_recover_to_trail()


func _recover_to_trail() -> void:
	if not _current_target_valid:
		return
	global_position = _current_target_point
	velocity = Vector2.ZERO
	_jumps_used = 0
	_jump_cooldown_timer = 0.0
	_stuck_timer = 0.0
	if debug_log:
		print("[ChaserEnemy] إنقاذ تلقائي: العدو كان عالق/طايح، تم إرجاعه لنقطة صالحة من مسار اللاعب.")


# ============================================================
#  نظام الصعوبة
# ============================================================
## نادِها من GameManager بعد كل نقطة حرجة (Critical Point) لرفع الصعوبة تدريجياً
func increase_difficulty() -> void:
	var max_level: int = DIFFICULTY_TABLE.size()
	if difficulty_level >= max_level:
		return
	difficulty_level += 1
	_apply_difficulty(difficulty_level)
	difficulty_changed.emit(difficulty_level)


func get_difficulty_level() -> int:
	return difficulty_level


func _apply_difficulty(level: int) -> void:
	var data: Dictionary = DIFFICULTY_TABLE.get(level, DIFFICULTY_TABLE[1])
	difficulty_level = level
	_trail_delay = data["trail_delay"]
	_catch_up_rate = data["catch_up_rate"]


# ============================================================
#  اكتشاف اللمس = Game Over
# ============================================================
func _check_catch_by_distance() -> void:
	if player == null or current_state == State.CATCH:
		return
	if global_position.distance_to(player.global_position) <= catch_distance:
		_trigger_catch()


func _on_catch_area_body_entered(body: Node) -> void:
	if current_state == State.CATCH:
		return
	if body == player or body.is_in_group("player"):
		_trigger_catch()
		$"../AudioStreamPlayer2".play()

func _trigger_catch() -> void:
	if current_state == State.CATCH:
		return
	current_state = State.CATCH
	velocity = Vector2.ZERO
	_play_sound(_growl_player)
	if debug_log:
		print("[ChaserEnemy] CATCH! العدو الآن مجمّد بانتظار GameManager. استدعِ reset_state() لإعادته للمطاردة.")
	player_caught.emit()
	state_changed.emit(current_state)
	# ملاحظة: GameManager يجب أن يستمع لإشارة player_caught ليتولى عرض
	# واجهة الـ Game Over، إيقاف اللعبة، الخ. هذا السكريبت لا يلمس الـ UI إطلاقاً


# ============================================================
#  التحكم الخارجي (يُستدعى من GameManager)
# ============================================================
func set_chase_enabled(enabled: bool) -> void:
	chase_enabled = enabled


func is_caught() -> bool:
	return current_state == State.CATCH


## استدعِها من GameManager بعد ما تعالج نتيجة الإمساك (Game Over / Respawn)
## لإعادة العدو لحالة المطاردة الطبيعية، وتصفير شريط المسار المسجَّل
## (وإلا العدو راح يحاول "يلحق" مساراً قديماً من قبل الإعادة)
func reset_state(new_position: Vector2 = Vector2.INF) -> void:
	current_state = State.IDLE
	velocity = Vector2.ZERO
	_trail.clear()
	_trail_start_index = 0
	_write_index = 0
	_read_cursor = 0.0
	_jumps_used = 0
	_jump_cooldown_timer = 0.0
	_was_on_floor = true
	_stuck_timer = 0.0
	_current_target_valid = false
	if new_position != Vector2.INF:
		global_position = new_position
	if debug_log:
		print("[ChaserEnemy] reset_state() — العدو رجع يلاحق من جديد")


# ============================================================
#  آلة الحالات (تبقى للإشارات/المنطق الخارجي فقط — لا تؤثر على الأنيميشن)
# ============================================================
func _update_state() -> void:
	if current_state == State.CATCH:
		return

	var previous_state: State = current_state

	if not is_on_floor():
		current_state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif abs(velocity.x) > 10.0:
		current_state = State.RUN
	else:
		current_state = State.IDLE

	if previous_state != current_state:
		_on_state_entered(current_state, previous_state)


func _on_state_entered(new_state: State, old_state: State) -> void:
	var was_airborne: bool = old_state == State.JUMP or old_state == State.FALL
	var now_grounded: bool = new_state == State.RUN or new_state == State.IDLE
	if was_airborne and now_grounded:
		_play_sound(_land_player)
	state_changed.emit(new_state)


# ============================================================
#  الأنيميشن — أنيميشن الركض فقط، يعمل دائماً
# ============================================================
func _update_animation() -> void:
	if not _animated_sprite:
		return
	if anim_run == "" or not _animated_sprite.sprite_frames:
		return
	if not _animated_sprite.sprite_frames.has_animation(anim_run):
		return  # تجاهل بصمت لو الاسم غير موجود
	if _animated_sprite.animation != anim_run or not _animated_sprite.is_playing():
		_animated_sprite.play(anim_run)


# ============================================================
#  الصوت — خطى مستمرة أثناء الجري + زئير عشوائي دوري
# ============================================================
func _update_footsteps(delta: float) -> void:
	if not enable_footsteps or current_state != State.RUN:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_play_sound(_footstep_player)
		_footstep_timer = footstep_interval


func _update_growl(delta: float) -> void:
	if current_state == State.CATCH:
		return
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_play_sound(_growl_player)
		_reset_growl_timer()


func _reset_growl_timer() -> void:
	_growl_timer = randf_range(growl_interval_min, growl_interval_max)


func _play_sound(player_node: AudioStreamPlayer2D) -> void:
	if player_node and player_node.stream and not player_node.playing:
		player_node.play()


# ============================================================
#  التصحيح البصري (Debug Draw)
# ============================================================
func _draw() -> void:
	if not debug_draw or Engine.is_editor_hint():
		return

	# رسم جزء من المسار المسجَّل (النقاط المتبقية أمام رأس القراءة) كخط
	# منقّط أصفر، ونقطة اللحاق الحالية كدائرة حمراء
	var local_index: int = clampi(int(_read_cursor) - _trail_start_index, 0, max(_trail.size() - 1, 0))
	if _trail.size() > local_index:
		var prev_point: Vector2 = to_local(_trail[local_index])
		draw_circle(prev_point, 4.0, Color.RED)
		var i: int = local_index
		while i < _trail.size() - 1:
			var a: Vector2 = to_local(_trail[i])
			var b: Vector2 = to_local(_trail[i + 1])
			draw_line(a, b, Color(1.0, 1.0, 0.0, 0.5), 1.5)
			i += 1

	if player:
		draw_line(Vector2.ZERO, to_local(player.global_position), Color.CYAN, 1.0)
