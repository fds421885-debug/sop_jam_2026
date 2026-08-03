@tool
class_name AutoScrollCamera
extends Camera2D
@onready var gameover: CanvasLayer = $"../gameover"

## ============================================================
## كاميرا تمشي بثبات (Auto-Scroll Camera) — تدفع اللاعب للأمام دائماً
## ============================================================
## الفكرة: الكاميرا تتحرك أفقياً بسرعة ثابتة (تتسارع تدريجياً لو حبيت)
## بغض النظر تماماً عن مكان اللاعب — ما ترجع للخلف أبداً وما تنتظره.
##
## طرفا التهديد:
## 1) الحافة الخلفية (يسار): لو اللاعب تخلّف عنها بمسافة أكبر من
##    kill_margin يخسر فوراً (إشارة player_left_behind).
## 2) الحافة الأمامية (يمين): اللاعب ما "يسبق" الكاميرا — بس بدون أي
##    حاجز/Collider يوقفه فيزيائياً. بدل كذا، لما اللاعب يقرب من الحافة
##    اليمنى للشاشة، الكاميرا نفسها تتسارع مؤقتاً (كاتش أب) لين تصير
##    سرعتها قريبة من سرعة اللاعب فتضل تلاحقه وما تخليه يطلع بره الإطار
##    — إحساس "الكاميرا تلحقني" مو "فيه جدار قدامي".
##
## حدود العالم (Bounds):
## بدل ما تكتب أرقام يدوياً، حط أربع عقد Node2D/Marker2D بالمشهد — وحدة
## عند أقصى يسار المرحلة، وحدة عند أقصى يمينها، وحدة عند أعلى نقطة
## مسموحة، وحدة عند أسفل نقطة مسموحة — وحدد مساراتهم بـ bounds_left_path
## / bounds_right_path / bounds_top_path / bounds_bottom_path. كل حد
## مستقل عن البقية: تقدر تحط بس اليسار واليمين (حد أفقي بدون رأسي)، أو
## بس الأعلى والأسفل، أو الأربعة مع بعض. الكاميرا تقرأ مواقعهم مرة عند
## البداية وتستخدمها كحدود صلبة ما تتعداها أبداً — سواء بالسحب التلقائي
## أو بالتتبع الرأسي.
##
## رأسياً (Y) الكاميرا تتبع اللاعب بسلاسة (smoothing) عادي.
##
## إعداد المشهد المطلوب:
## 1) ضع اللاعب ضمن المجموعة "player" (نفس مجموعة سكريبت ChaserEnemy)
## 2) خلي هذا الـ Camera2D هو current = true بالمشهد
## 3) (اختياري لكن موصى فيه) أضف أربع عقد Node2D لتحديد حدود المرحلة
##    وحددهم بـ bounds_left_path / bounds_right_path / bounds_top_path / bounds_bottom_path
## 4) استمع لإشارة player_left_behind من GameManager لعرض Game Over
##    (بالضبط زي ما تستمع لإشارة player_caught من ChaserEnemy)
##
## نصيحة: لو تبي الكاميرا "تسرّع" مع نفس نظام صعوبة العدو، وصّل إشارة
## difficulty_changed من ChaserEnemy باستدعاء زيادة max_scroll_speed أو
## acceleration من GameManager — السكريبتين مستقلّين عن بعض بالكامل.

@export_group("Scroll")
@export var scroll_speed: float = 90.0
## سرعة تحرك الكاميرا الأفقية الثابتة (px/s) عند البداية — لا تتوقف ولا ترجع للخلف أبداً
@export var accelerate_over_time: bool = true
@export var acceleration: float = 2.5
## زيادة تدريجية بسرعة السحب (px/s²) كل ثانية تمر باللعبة — الضغط يزيد كل ما طال الوقت
@export var max_scroll_speed: float = 260.0

@export_group("Vertical Follow")
@export var follow_vertical: bool = true
@export var vertical_smoothing: float = 6.0
## كل ما زاد الرقم، الكاميرا تلحق اللاعب رأسياً أسرع (0 = تجمّد رأسياً بلا تتبع)

@export_group("World Bounds")
@export var bounds_left_path: NodePath
## عقدة (Node2D/Marker2D) — يُقرأ منها الإحداثي X فقط، يحدد أقصى حد لليسار
@export var bounds_right_path: NodePath
## عقدة (Node2D/Marker2D) — يُقرأ منها الإحداثي X فقط، يحدد أقصى حد لليمين
@export var bounds_top_path: NodePath
## عقدة (Node2D/Marker2D) — يُقرأ منها الإحداثي Y فقط، يحدد أقصى حد للأعلى
@export var bounds_bottom_path: NodePath
## عقدة (Node2D/Marker2D) — يُقرأ منها الإحداثي Y فقط، يحدد أقصى حد للأسفل
## كل حد مستقل عن البقية — تقدر تحط بس اليسار واليمين، أو بس الأعلى
## والأسفل، أو الأربعة مع بعض. أي حد مفقود (NodePath فاضي) يُتجاهل ولا يُطبَّق
@export var clamp_horizontal: bool = true
@export var clamp_vertical: bool = true

@export_group("Kill Zone (Trailing Edge)")
@export var kill_check_enabled: bool = true
@export var kill_margin: float = 40.0
## أقصى مسافة (بيكسل) يُسمح فيها للاعب يكون خلف الحافة اليسرى للشاشة
## قبل ما يُعتبر "خسر" — 0 يعني يخسر بمجرد ما يطلع خارج الشاشة تماماً

@export_group("Leading Edge (تسريع الكاميرا بدل حاجز)")
@export var leading_edge_catchup_enabled: bool = true
@export var leading_edge_margin: float = 60.0
## المسافة (بيكسل) من الحافة اليمنى للشاشة — لما اللاعب يدخل هالمسافة، تبدأ الكاميرا تتسارع لتلحقه
@export var catchup_zone_width: float = 160.0
## عرض منطقة "الإنذار" (بيكسل) قبل الحافة — كل ما اللاعب يقرب أكثر داخلها، تتسارع الكاميرا أكثر
@export var catchup_max_boost: float = 260.0
## أقصى سرعة إضافية (px/s) تُضاف فوق السرعة العادية وقت اللحاق
@export var catchup_acceleration: float = 900.0
## معدل زيادة سرعة اللحاق (px/s²) كل ما اقترب اللاعب من الحافة
@export var catchup_decay: float = 500.0
## معدل تلاشي سرعة اللحاق (px/s²) لما اللاعب يبتعد عن الحافة ويرجع لمنطقة آمنة

@export_group("Node References")
@export var player_path: NodePath   ## اختياري — لو فاضي، يدوّر تلقائياً بمجموعة "player"

@export_group("Debug")
@export var debug_draw: bool = false
@export var debug_log: bool = true

signal player_left_behind    ## يُلتقط من GameManager لعرض Game Over (نفس فكرة player_caught بـ ChaserEnemy)

var player: Node2D = null
var _base_scroll_speed: float = 0.0
var _catchup_boost: float = 0.0
var _current_scroll_speed: float = 0.0
var _player_search_timer: float = 0.0
var _has_triggered_loss: bool = false

var _has_horizontal_bounds: bool = false
var _has_vertical_bounds: bool = false
var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_base_scroll_speed = scroll_speed
	_current_scroll_speed = scroll_speed
	_find_player()
	_read_bounds()


func _find_player() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path)
	if player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if debug_log:
		if player:
			print("[AutoScrollCamera] player found: ", player.name)
		else:
			print("[AutoScrollCamera] WARNING: لا يوجد عقدة بمجموعة 'player' ولا player_path صحيح.")
			gameover.visible = true

## يقرأ موقع عقد الحدود الأربعة مرة وحدة عند البداية. كل محور (أفقي/رأسي)
## مستقل: لو وحدة بس من عقدتَي المحور موجودة، ما يُطبَّق حد على ذاك
## المحور إطلاقاً (لازم كل الطرفين موجودين عشان يصير فيه حد صالح)
func _read_bounds() -> void:
	var left_node: Node2D = get_node_or_null(bounds_left_path) as Node2D
	var right_node: Node2D = get_node_or_null(bounds_right_path) as Node2D
	var top_node: Node2D = get_node_or_null(bounds_top_path) as Node2D
	var bottom_node: Node2D = get_node_or_null(bounds_bottom_path) as Node2D

	_has_horizontal_bounds = left_node != null and right_node != null
	if _has_horizontal_bounds:
		_bounds_min.x = left_node.global_position.x
		_bounds_max.x = right_node.global_position.x

	_has_vertical_bounds = top_node != null and bottom_node != null
	if _has_vertical_bounds:
		_bounds_min.y = top_node.global_position.y
		_bounds_max.y = bottom_node.global_position.y

	if debug_log:
		if _has_horizontal_bounds:
			print("[AutoScrollCamera] حد أفقي: من ", _bounds_min.x, " إلى ", _bounds_max.x)
		else:
			print("[AutoScrollCamera] لا يوجد حد أفقي (bounds_left_path / bounds_right_path) — سحب بلا سقف أفقي.")
		if _has_vertical_bounds:
			print("[AutoScrollCamera] حد رأسي: من ", _bounds_min.y, " إلى ", _bounds_max.y)
		else:
			print("[AutoScrollCamera] لا يوجد حد رأسي (bounds_top_path / bounds_bottom_path) — تتبع بلا سقف رأسي.")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if player == null:
		_player_search_timer -= delta
		if _player_search_timer <= 0.0:
			_find_player()
			_player_search_timer = 0.5

	if _has_triggered_loss:
		return  # توقف عن التحديث بعد الخسارة، بانتظار GameManager

	# تسارع تدريجي اختياري بالسرعة الأساسية — كل ما طال الوقت، الضغط أكبر
	if accelerate_over_time:
		_base_scroll_speed = min(_base_scroll_speed + acceleration * delta, max_scroll_speed)

	# لحاق مؤقت: لو اللاعب قرب من الحافة اليمنى، تضيف الكاميرا سرعة إضافية
	# فوق الأساسية بدل ما تحط أي حاجز يوقفه
	if leading_edge_catchup_enabled and player != null:
		_update_leading_edge_catchup(delta)
	else:
		_catchup_boost = move_toward(_catchup_boost, 0.0, catchup_decay * delta)

	_current_scroll_speed = _base_scroll_speed + _catchup_boost

	# الكاميرا تمشي للأمام دائماً — بلا شرط، بلا انتظار، بلا رجوع للخلف
	global_position.x += _current_scroll_speed * delta

	# تتبع رأسي سلس فقط (التهديد كله أفقي)
	if follow_vertical and player != null and vertical_smoothing > 0.0:
		global_position.y = lerp(global_position.y, player.global_position.y, clampf(vertical_smoothing * delta, 0.0, 1.0))

	_apply_bounds()

	if kill_check_enabled and player != null:
		_check_player_left_behind()

	if debug_draw:
		queue_redraw()


## يمنع مركز الكاميرا (وبالتالي حواف الشاشة) من تجاوز مستطيل الحدود —
## لو وصلت الكاميرا لنهاية المرحلة، تتوقف عن التقدم تلقائياً بدل ما تكشف
## خارج المستوى
func _apply_bounds() -> void:
	if not _has_horizontal_bounds and not _has_vertical_bounds:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var half_width: float = (viewport_size.x * 0.5) / zoom.x
	var half_height: float = (viewport_size.y * 0.5) / zoom.y

	if clamp_horizontal and _has_horizontal_bounds:
		var min_x: float = _bounds_min.x + half_width
		var max_x: float = _bounds_max.x - half_width
		if min_x <= max_x:
			global_position.x = clampf(global_position.x, min_x, max_x)

	if clamp_vertical and _has_vertical_bounds:
		var min_y: float = _bounds_min.y + half_height
		var max_y: float = _bounds_max.y - half_height
		if min_y <= max_y:
			global_position.y = clampf(global_position.y, min_y, max_y)


## يحسب مدى "إلحاح" اللحاق بناءً على قرب اللاعب من الحافة اليمنى، ويرفع
## _catchup_boost تدريجياً (لا قفزة سرعة مفاجئة) — كل ما اللاعب أقرب
## للحافة، تتسارع الكاميرا أكثر لتقصّر المسافة بدل ما توقفه بحاجز
func _update_leading_edge_catchup(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_width: float = (viewport_size.x * 0.5) / zoom.x
	var leading_edge_x: float = global_position.x + half_width - leading_edge_margin
	var catchup_start_x: float = leading_edge_x - catchup_zone_width

	var player_x: float = player.global_position.x

	if player_x <= catchup_start_x:
		# اللاعب بمنطقة آمنة، بعيد عن الحافة — تلاشي سرعة اللحاق تدريجياً
		_catchup_boost = move_toward(_catchup_boost, 0.0, catchup_decay * delta)
		return

	# نسبة الإلحاح من 0 (بداية منطقة الإنذار) إلى 1 (لاصق بالحافة تماماً)
	var urgency: float = clampf((player_x - catchup_start_x) / catchup_zone_width, 0.0, 1.0)
	var target_boost: float = catchup_max_boost * urgency

	if target_boost > _catchup_boost:
		_catchup_boost = min(_catchup_boost + catchup_acceleration * delta, target_boost)
	else:
		_catchup_boost = max(_catchup_boost - catchup_decay * delta, target_boost)


func _check_player_left_behind() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_width: float = (viewport_size.x * 0.5) / zoom.x
	var left_edge_x: float = global_position.x - half_width

	if player.global_position.x < left_edge_x - kill_margin:
		_trigger_loss()


func _trigger_loss() -> void:
	if _has_triggered_loss:
		return
	_has_triggered_loss = true
	if debug_log:
		print("[AutoScrollCamera] اللاعب اتخلف عن الكاميرا — خسارة فورية.")
	player_left_behind.emit()
	gameover.visible = true
	get_tree().paused = true
	$"../AudioStreamPlayer2".play()


## نادِها من GameManager بعد إعادة اللاعب لبداية جديدة (Respawn / مرحلة جديدة)
func reset_state(new_position: Vector2 = Vector2.INF) -> void:
	_has_triggered_loss = false
	_base_scroll_speed = scroll_speed
	_catchup_boost = 0.0
	_current_scroll_speed = scroll_speed
	if new_position != Vector2.INF:
		global_position = new_position
	_apply_bounds()


func is_player_lost() -> bool:
	return _has_triggered_loss


func _draw() -> void:
	if not debug_draw or Engine.is_editor_hint():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_width: float = (viewport_size.x * 0.5) / zoom.x
	var half_height: float = (viewport_size.y * 0.5) / zoom.y

	# خط الخسارة (الحافة اليسرى)
	var local_left: float = -half_width - kill_margin
	draw_line(Vector2(local_left, -half_height), Vector2(local_left, half_height), Color.RED, 2.0)

	# بداية منطقة الإنذار وحافة اللحاق (يمين) — بدون حاجز فعلي، بس تصور بصري لمنطقة تسريع الكاميرا
	var local_leading_edge: float = half_width - leading_edge_margin
	var local_catchup_start: float = local_leading_edge - catchup_zone_width
	draw_line(Vector2(local_leading_edge, -half_height), Vector2(local_leading_edge, half_height), Color(0.2, 0.6, 1.0), 2.0)
	draw_line(Vector2(local_catchup_start, -half_height), Vector2(local_catchup_start, half_height), Color(0.2, 0.6, 1.0, 0.4), 1.0)
