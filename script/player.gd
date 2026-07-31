extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -450.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# إعدادات الحركة والقدرات
@export var double_jump_boost_multiplier: float = 0.2 
@export var dash_speed: float = 1200.0
@export var wall_slide_gravity_factor: float = 0.1 

# نسبة تباطؤ الزمن (كل ما قللت الرقم، كل ما صار أبطأ، مثلاً 0.5 يعني نصف السرعة)
@export var slow_mo_factor: float = 0.4 

# تحكم منفصل في وقت كل قدرة (بالثواني)
@export_group("Abilities Timers")
@export var time_double_jump: float = 15.0
@export var time_glide: float = 12.0
@export var time_dash: float = 10.0
@export var time_wall_slide: float = 15.0
@export var time_shock_wave: float = 10.0
@export var time_slow_mo: float = 8.0

# وقت الانتقال أو اختيار القدرة العشوائية (الروليت)
@export var random_selection_duration: float = 3.0 

var all_abilities: Array[String] = [
	"double_jump", 
	"glide", 
	"dash", 
	"wall_slide", 
	"shock_wave", 
	"slow_mo"
]

var current_ability: String = "double_jump"
var ability_timer: float = 0.0 
var max_ability_time: float = 15.0 

var can_double_jump: bool = true
var is_gliding: bool = false
var is_dashing: bool = false
var is_slow_mo_active: bool = false
var last_facing_dir: float = 1.0
var is_selecting_random: bool = false 

# مسارات الواجهة
@onready var instability_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var ability_label: Label = $CanvasLayer/Control/AbilityLabel
@onready var ability_icon: TextureRect = $CanvasLayer/Control/AbilityIcon

# عقدة درع الحماية المحيط
@onready var shockwave_area: Area2D = $ShockwaveArea

# مرجع الكاميرا (افترضنا أنها موجودة كعقدة فرعية Camera2D تحت اللاعب)
@onready var camera: Camera2D = $Camera2D

# الأيقونات
@export var icon_double_jump: Texture2D
@export var icon_glide: Texture2D
@export var icon_dash: Texture2D
@export var icon_wall_slide: Texture2D
@export var icon_shock_wave: Texture2D
@export var icon_slow_mo: Texture2D

func _ready() -> void:
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
	if is_selecting_random:
		return

	var time_modifier = slow_mo_factor if is_slow_mo_active else 1.0
	ability_timer -= delta * time_modifier
	
	if ability_timer <= 0:
		start_random_ability_sequence()
		return

	update_ui()

	if current_ability == "slow_mo":
		if Input.is_action_just_pressed("slow_mo") or Input.is_key_pressed(KEY_Q):
			is_slow_mo_active = !is_slow_mo_active

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
	
	if not is_on_floor():
		if is_gliding:
			current_gravity *= 0.3
		elif current_ability == "wall_slide" and is_on_wall() and velocity.y > 0:
			current_gravity *= wall_slide_gravity_factor
			
		velocity.y += current_gravity * delta
	else:
		can_double_jump = true
		is_gliding = false

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
		else:
			if current_ability != "dash" and current_ability != "wall_slide":
				handle_air_abilities()

	if current_ability == "shock_wave" and Input.is_key_pressed(KEY_E):
		activate_shock_wave()

	var current_speed = speed * (slow_mo_factor if is_slow_mo_active else 1.0)
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	if is_slow_mo_active:
		velocity.y *= slow_mo_factor * 0.5

	move_and_slide()

func set_ability_timer_duration(ab_name: String) -> void:
	match ab_name:
		"double_jump": max_ability_time = time_double_jump
		"glide": max_ability_time = time_glide
		"dash": max_ability_time = time_dash
		"wall_slide": max_ability_time = time_wall_slide
		"shock_wave": max_ability_time = time_shock_wave
		"slow_mo": max_ability_time = time_slow_mo
		_: max_ability_time = 15.0

func handle_air_abilities() -> void:
	if current_ability == "double_jump" and can_double_jump:
		var boosted_jump = jump_velocity * (1.0 + double_jump_boost_multiplier)
		if is_slow_mo_active: boosted_jump *= slow_mo_factor 
		velocity.y = boosted_jump
		can_double_jump = false
	elif current_ability == "glide":
		is_gliding = true

func start_hollow_knight_dash() -> void:
	is_dashing = true
	is_gliding = false
	var dash_dir = last_facing_dir
	if Input.is_action_pressed("ui_left"): dash_dir = -1.0
	elif Input.is_action_pressed("ui_right"): dash_dir = 1.0
		
	last_facing_dir = dash_dir
	var current_dash_speed = dash_speed * (slow_mo_factor if is_slow_mo_active else 1.0)
	velocity.x = current_dash_speed * dash_dir
	velocity.y = 0 
	
	var timer_wait = 0.15 / (slow_mo_factor if is_slow_mo_active else 1.0)
	await get_tree().create_timer(timer_wait).timeout
	is_dashing = false

func activate_shock_wave() -> void:
	if shockwave_area and shockwave_area.monitoring:
		return
		
	if shockwave_area:
		shockwave_area.position = Vector2.ZERO 
		shockwave_area.monitoring = true
		shockwave_area.visible = true
		
		var timer_wait = 0.3 / (slow_mo_factor if is_slow_mo_active else 1.0)
		await get_tree().create_timer(timer_wait).timeout
		
		if shockwave_area:
			shockwave_area.monitoring = false
			shockwave_area.visible = false

func _on_shockwave_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.has_method("die"):
		body.queue_free()

func start_random_ability_sequence() -> void:
	is_selecting_random = true
	is_slow_mo_active = false
	is_gliding = false
	
	if ability_label:
		ability_label.text = "سيتم اختيار قدرة عشوائية..."
	
	var step_time = random_selection_duration / 6.0
	for i in range(6):
		if ability_icon:
			var random_preview = all_abilities[randi() % all_abilities.size()]
			ability_icon.texture = get_ability_icon(random_preview)
		await get_tree().create_timer(step_time).timeout
	
	var available_choices = []
	for ab in all_abilities:
		if ab != current_ability:
			available_choices.append(ab)
	
	available_choices.shuffle()
	var chosen_ability = available_choices[0]
	
	select_new_ability(chosen_ability)

func select_new_ability(new_ability_name: String) -> void:
	is_selecting_random = false
	current_ability = new_ability_name
	
	set_ability_timer_duration(current_ability)
	ability_timer = max_ability_time 
	
	is_gliding = false
	is_dashing = false
	is_slow_mo_active = false
	
	# تشغيل هزة الكاميرا القوية عند استقرار القدرة الجديدة
	shake_camera(0.4, 15.0)
	
	update_ui()

# دالة هزة الكاميرا (duration: المدة بالثانية، intensity: قوة الهزة بالبكسل)
func shake_camera(duration: float, intensity: float) -> void:
	if not camera:
		return
	
	var original_offset = camera.offset
	var elapsed_time = 0.0
	
	while elapsed_time < duration:
		if not camera: 
			break
		camera.offset = original_offset + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		elapsed_time += get_process_delta_time()
		await get_tree().process_frame
	
	if camera:
		camera.offset = original_offset

func get_ability_icon(ab_name: String) -> Texture2D:
	match ab_name:
		"double_jump": return icon_double_jump
		"glide": return icon_glide
		"dash": return icon_dash
		"wall_slide": return icon_wall_slide
		"shock_wave": return icon_shock_wave
		"slow_mo": return icon_slow_mo
	return null

func update_ui() -> void:
	if is_selecting_random: 
		return
	
	if instability_bar:
		var progress_percent = (ability_timer / max_ability_time) * 100.0
		instability_bar.value = progress_percent
		
		if ability_timer <= 3.0:
			instability_bar.modulate = Color(1, 0, 0) 
		else:
			instability_bar.modulate = Color(1, 1, 1) 
		
	if ability_label:
		var name_text = ""
		match current_ability:
			"double_jump": name_text = "قفزة مزدوجة"
			"glide": name_text = "انزلاق هوائي"
			"dash": name_text = "داش سريع [Shift]"
			"wall_slide": name_text = "التصاق جداري"
			"shock_wave": name_text = "درع الحماية المحيط [زر E]"
			"slow_mo": name_text = "تباطؤ الزمن [زر Q] (نشط)" if is_slow_mo_active else "تباطؤ الزمن [زر Q]"
			_: name_text = current_ability
		
		ability_label.text = name_text + " | باقي: " + str(int(ability_timer)) + "ث"

	if ability_icon:
		ability_icon.texture = get_ability_icon(current_ability)
