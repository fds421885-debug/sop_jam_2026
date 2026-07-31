extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -450.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# إعدادات التوازن والقدرات الخاصة
@export_group("Ability Custom Settings")
@export var max_uses_before_critical: int = 4 
@export var double_jump_boost_multiplier: float = 0.2 
@export var dash_speed: float = 1200.0
@export var slow_mo_duration: float = 10.0 
@export var slow_mo_gravity_scale: float = 0.2 
@export var wall_slide_gravity_factor: float = 0.1 # تحكم في سرعة الالتصاق بالجدار (قللها أو زودها من هنا)

# ربط الأزرار من الـ Inspector
@export_group("UI Buttons")
@export var btn_1: Button
@export var btn_2: Button

var all_abilities: Array[String] = [
	"double_jump", 
	"glide", 
	"dash", 
	"wall_slide", 
	"shock_wave", 
	"slow_mo"
]

var current_ability: String = "double_jump"
var ability_level: int = 1
var ability_uses: int = 0
var instability: float = 0.0

var can_double_jump: bool = true
var is_gliding: bool = false
var is_dashing: bool = false
var is_slow_mo_active: bool = false
var last_facing_dir: float = 1.0

# مسارات الواجهة والعقد
@onready var instability_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var ability_label: Label = $CanvasLayer/Control/AbilityLabel
@onready var ability_icon: TextureRect = $CanvasLayer/Control/AbilityIcon
@onready var choice_screen: Control = $CanvasLayer/ChoiceScreen

# عقد درع الانعكاس والنصلين
@onready var shockwave_area: Area2D = $ShockwaveArea
@onready var shockwave_sprite: Sprite2D = $ShockwaveArea/Sprite2D
@onready var shockwave_collision: CollisionShape2D = $ShockwaveArea/CollisionShape2D

# الأيقونات
@export var icon_double_jump: Texture2D
@export var icon_glide: Texture2D
@export var icon_dash: Texture2D
@export var icon_wall_slide: Texture2D
@export var icon_shock_wave: Texture2D
@export var icon_slow_mo: Texture2D

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
	
	if btn_1: btn_1.pressed.connect(_on_btn_1_clicked)
	if btn_2: btn_2.pressed.connect(_on_btn_2_clicked)
	
	if shockwave_area:
		shockwave_area.monitoring = false
		shockwave_area.visible = false
		if not shockwave_area.body_entered.is_connected(_on_shockwave_body_entered):
			shockwave_area.body_entered.connect(_on_shockwave_body_entered)
	
	update_ui()

func _physics_process(delta: float) -> void:
	if is_slow_mo_active:
		var fill_speed = 100.0 / slow_mo_duration 
		instability += fill_speed * delta
		update_ui()
		
		if instability >= 100.0:
			instability = 100.0
			is_slow_mo_active = false
			trigger_critical_point()
			return

	if current_ability == "slow_mo" and not is_slow_mo_active and not choice_screen.visible:
		if Input.is_action_just_pressed("slow_mo") or Input.is_key_pressed(KEY_Q):
			activate_slow_motion()

	if current_ability == "dash" and not is_dashing:
		if Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_SHIFT):
			start_hollow_knight_dash()

	if is_dashing:
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		last_facing_dir = direction

	var current_gravity = gravity
	if is_slow_mo_active:
		current_gravity *= slow_mo_gravity_scale
	
	if not is_on_floor():
		if is_gliding:
			current_gravity *= 0.3
			register_continuous_use(delta * 5.0) 
		elif current_ability == "wall_slide" and is_on_wall() and velocity.y > 0:
			# استخدام المتغير المعرّف للتحكم في سرعة النزول على الجدار
			current_gravity *= wall_slide_gravity_factor
			register_continuous_use(delta * 3.0) 
			
		velocity.y += current_gravity * delta
	else:
		can_double_jump = true
		is_gliding = false

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			velocity.y -= float(ability_level - 1) * 10.0
		else:
			if current_ability != "dash" and current_ability != "wall_slide":
				handle_air_abilities()

	if current_ability == "shock_wave" and Input.is_key_pressed(KEY_E):
		activate_shock_wave()

	if direction:
		var current_speed = speed * (0.6 if is_slow_mo_active else 1.0)
		velocity.x = direction * current_speed
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

func start_hollow_knight_dash() -> void:
	is_dashing = true
	is_gliding = false
	var dash_dir = last_facing_dir
	if Input.is_action_pressed("ui_left"): dash_dir = -1.0
	elif Input.is_action_pressed("ui_right"): dash_dir = 1.0
		
	last_facing_dir = dash_dir
	velocity.x = dash_speed * dash_dir
	velocity.y = 0 
	register_ability_use()
	await get_tree().create_timer(0.15).timeout
	is_dashing = false

func activate_shock_wave() -> void:
	if shockwave_area and shockwave_area.monitoring:
		return
		
	print("🛡️⚔️ Shockwave Blades Released!")
	
	if shockwave_area:
		# جعل مساحة النصل تظهر وتتجه حسب مكان وجهة اللاعب الأخيرة
		shockwave_area.position.x = last_facing_dir * 50.0 
		shockwave_area.monitoring = true
		shockwave_area.visible = true
		
		await get_tree().create_timer(0.2).timeout
		
		if shockwave_area:
			shockwave_area.monitoring = false
			shockwave_area.visible = false
			
	register_ability_use()

func _on_shockwave_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.has_method("die"):
		print("💀 Enemy destroyed by Shockwave Blades!")
		body.queue_free()

func activate_slow_motion() -> void:
	is_slow_mo_active = true

func register_ability_use() -> void:
	if is_slow_mo_active: return 
	
	ability_uses += 1
	ability_level = int(float(ability_uses) / 2.0) + 1
	
	var usage_step = 100.0 / float(max_uses_before_critical)
	instability += usage_step
	
	update_ui()
	
	if instability >= 100.0:
		trigger_critical_point()

func register_continuous_use(amount: float) -> void:
	if is_slow_mo_active: return
	
	instability += amount
	update_ui()
	if instability >= 100.0:
		trigger_critical_point()

func update_ui() -> void:
	if instability_bar:
		instability_bar.value = instability
		
	if ability_label:
		var name_text = ""
		match current_ability:
			"double_jump": name_text = "قفزة مزدوجة [Space]"
			"glide": name_text = "انزلاق هوائي [Space]"
			"dash": name_text = "داش سريع [Shift]"
			"wall_slide": name_text = "التصاق جداري"
			"shock_wave": name_text = "درع الانعكاس والنصلين [زر E]"
			"slow_mo": name_text = "تباطؤ الزمن [زر Q] (نشط)" if is_slow_mo_active else "تباطؤ الزمن [زر Q]"
			_: name_text = current_ability
		
		ability_label.text = name_text + " | مستوى " + str(ability_level)

	if ability_icon:
		match current_ability:
			"double_jump": ability_icon.texture = icon_double_jump
			"glide": ability_icon.texture = icon_glide
			"dash": ability_icon.texture = icon_dash
			"wall_slide": ability_icon.texture = icon_wall_slide
			"shock_wave": ability_icon.texture = icon_shock_wave
			"slow_mo": ability_icon.texture = icon_slow_mo

func trigger_critical_point() -> void:
	print("💥 CRITICAL POINT! القدرة انهارت تماماً!")
	
	var remaining_abilities = []
	for ab in all_abilities:
		if ab != current_ability:
			remaining_abilities.append(ab)
	
	remaining_abilities.shuffle()
	
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
		"double_jump": return "اختر: قفزة مزدوجة"
		"glide": return "اختر: انزلاق هوائي"
		"dash": return "اختر: داش سريع"
		"wall_slide": return "اختر: التصاق جداري"
		"shock_wave": return "اختر: درع الانعكاس والنصلين"
		"slow_mo": return "اختر: تباطؤ الزمن"
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
	is_slow_mo_active = false
	
	if choice_screen:
		choice_screen.visible = false
	
	update_ui()
