extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -450.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# إعدادات قابلة للتعديل من الـ Inspector
@export_group("Ability Balancing & Settings")
@export var max_uses_before_critical: int = 4 
@export var double_jump_boost_multiplier: float = 0.2 
@export var dash_speed: float = 1200.0

# ربط الأزرار من الـ Inspector بالسحب والإفلات
@export_group("UI Buttons")
@export var btn_1: Button
@export var btn_2: Button

# متغيرات النظام
var current_ability: String = "double_jump"
var ability_level: int = 1
var ability_uses: int = 0
var instability: float = 0.0

var can_double_jump: bool = true
var is_gliding: bool = false
var is_dashing: bool = false
var last_facing_dir: float = 1.0

# مسارات الواجهة الأخرى
@onready var instability_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var ability_label: Label = $CanvasLayer/Control/AbilityLabel
@onready var ability_icon: TextureRect = $CanvasLayer/Control/AbilityIcon
@onready var choice_screen: Control = $CanvasLayer/ChoiceScreen

# الأيقونات
@export var icon_double_jump: Texture2D
@export var icon_glide: Texture2D
@export var icon_dash: Texture2D

# متغيرات لحفظ القدرات التي ستُسند للزرين مؤقتاً
var ability_assigned_to_btn1: String = ""
var ability_assigned_to_btn2: String = ""

func _ready() -> void:
	if instability_bar:
		instability_bar.min_value = 0
		instability_bar.max_value = 100
		instability_bar.value = 0
	
	if choice_screen:
		choice_screen.visible = false
		choice_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# ربط الزرين برمجياً للتأكد إنهم يشتغلون (مع فحص هل تم سحبهم في الإنسبيكتور ولا لا)
	if btn_1:
		btn_1.pressed.connect(_on_btn_1_clicked)
	else:
		print("⚠️ تحذير: زر Btn1 غير مربوط في الـ Inspector!")
		
	if btn_2:
		btn_2.pressed.connect(_on_btn_2_clicked)
	else:
		print("⚠️ تحذير: زر Btn2 غير مربوط في الـ Inspector!")
	
	update_ui()

func _physics_process(delta: float) -> void:
	if current_ability == "dash" and not is_dashing:
		if Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_SHIFT):
			start_hollow_knight_dash()

	if is_dashing:
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		last_facing_dir = direction

	if not is_on_floor():
		if is_gliding:
			velocity.y += gravity * 0.3 * delta
		else:
			velocity.y += gravity * delta
	else:
		can_double_jump = true
		is_gliding = false

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			velocity.y -= float(ability_level - 1) * 10.0
		else:
			if current_ability != "dash":
				handle_air_abilities()

	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

func handle_air_abilities() -> void:
	if current_ability == "double_jump" and can_double_jump:
		var boosted_jump = jump_velocity * (1.0 + (float(ability_level) * double_jump_boost_multiplier))
		velocity.y = boosted_jump
		can_double_jump = false
		register_ability_use()
	elif current_ability == "glide":
		is_gliding = true
		register_ability_use()

func start_hollow_knight_dash() -> void:
	is_dashing = true
	is_gliding = false
	
	var dash_dir = last_facing_dir
	if Input.is_action_pressed("ui_left"):
		dash_dir = -1.0
	elif Input.is_action_pressed("ui_right"):
		dash_dir = 1.0
		
	last_facing_dir = dash_dir
	velocity.x = dash_speed * dash_dir
	velocity.y = 0 
	
	register_ability_use()
	
	await get_tree().create_timer(0.15).timeout
	is_dashing = false

func register_ability_use() -> void:
	ability_uses += 1
	ability_level = int(float(ability_uses) / 2.0) + 1
	
	var usage_step = 100.0 / float(max_uses_before_critical)
	instability += usage_step
	
	update_ui()
	
	if instability >= 100.0:
		trigger_critical_point()

func update_ui() -> void:
	if instability_bar:
		instability_bar.value = instability
		
	if ability_label:
		var name_text = ""
		if current_ability == "double_jump":
			name_text = "قفزة مزدوجة [زر Space]"
		elif current_ability == "glide":
			name_text = "انزلاق [زر Space]"
		elif current_ability == "dash":
			name_text = "داش سريع [زر Shift]"
		
		ability_label.text = name_text + " | مستوى " + str(ability_level)

	if ability_icon:
		if current_ability == "double_jump" and icon_double_jump:
			ability_icon.texture = icon_double_jump
		elif current_ability == "glide" and icon_glide:
			ability_icon.texture = icon_glide
		elif current_ability == "dash" and icon_dash:
			ability_icon.texture = icon_dash

func trigger_critical_point() -> void:
	print("💥 CRITICAL POINT! القدرة انهارت تماماً!")
	
	var all_abilities = ["double_jump", "glide", "dash"]
	var remaining_abilities = []
	
	for ab in all_abilities:
		if ab != current_ability:
			remaining_abilities.append(ab)
	
	if remaining_abilities.size() >= 2:
		ability_assigned_to_btn1 = remaining_abilities[0]
		ability_assigned_to_btn2 = remaining_abilities[1]
		
		if btn_1: btn_1.text = get_ability_display_name(ability_assigned_to_btn1)
		if btn_2: btn_2.text = get_ability_display_name(ability_assigned_to_btn2)

	if choice_screen:
		choice_screen.visible = true
		
	get_tree().paused = true

func get_ability_display_name(ab_name: String) -> String:
	match ab_name:
		"double_jump": return "اختر: قفزة مزدوجة [Space]"
		"glide": return "اختر: انزلاق [Space]"
		"dash": return "اختر: داش سريع [Shift]"
		_: return "اختر: " + ab_name

func _on_btn_1_clicked() -> void:
	select_new_ability(ability_assigned_to_btn1)

func _on_btn_2_clicked() -> void:
	select_new_ability(ability_assigned_to_btn2)

func select_new_ability(new_ability_name: String) -> void:
	get_tree().paused = false
	
	current_ability = new_ability_name
	instability = 0.0
	ability_uses = 0
	ability_level = 1
	is_gliding = false
	is_dashing = false
	
	if choice_screen:
		choice_screen.visible = false
	
	update_ui()
