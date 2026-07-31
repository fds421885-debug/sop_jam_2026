extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -450.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# متغيرات نظام القدرات
var current_ability: String = "double_jump"
var ability_level: int = 1
var ability_uses: int = 0
var instability: float = 0.0

var can_double_jump: bool = true
var is_gliding: bool = false

# مسارات الواجهة المحدثة (تأكد من أسماء العقد عندك)
@onready var instability_bar: ProgressBar = $CanvasLayer/Control/ProgressBar
@onready var ability_label: Label = $CanvasLayer/Control/AbilityLabel
@onready var ability_icon: TextureRect = $CanvasLayer/Control/AbilityIcon

# أمثلة لصور أو أيقونات القدرات (تقدر تسحب صورك وتخليهم هنا أو تربطهم)
@export var icon_double_jump: Texture2D
@export var icon_glide: Texture2D
@export var icon_dash: Texture2D

func _ready() -> void:
	if instability_bar:
		instability_bar.min_value = 0
		instability_bar.max_value = 100
		instability_bar.value = 0
	
	update_ui()

func _physics_process(delta: float) -> void:
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
			velocity.y -= (ability_level - 1) * 20
		else:
			handle_air_abilities()

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

func handle_air_abilities() -> void:
	if current_ability == "double_jump" and can_double_jump:
		velocity.y = jump_velocity * 1.1
		can_double_jump = false
		register_ability_use()
	elif current_ability == "glide":
		is_gliding = true
		register_ability_use()
	elif current_ability == "dash":
		velocity.x += 600 * sign(velocity.x if velocity.x != 0 else 1)
		register_ability_use()

func register_ability_use() -> void:
	ability_uses += 1
	ability_level = int(ability_uses / 3) + 1
	instability += 25.0
	
	update_ui()
	
	if instability >= 100.0:
		trigger_critical_point()

func update_ui() -> void:
	if instability_bar:
		instability_bar.value = instability
		
	if ability_label:
		var name_text = "قفزة مزدوجة"
		if current_ability == "glide": name_text = "انزلاق (Glide)"
		elif current_ability == "dash": name_text = "داش (Dash)"
		
		ability_label.text = name_text + " (مستوى " + str(ability_level) + ")"

	if ability_icon:
		if current_ability == "double_jump" and icon_double_jump:
			ability_icon.texture = icon_double_jump
		elif current_ability == "glide" and icon_glide:
			ability_icon.texture = icon_glide
		elif current_ability == "dash" and icon_dash:
			ability_icon.texture = icon_dash

func trigger_critical_point() -> void:
	print("💥 CRITICAL POINT! القدرة انهارت تماماً!")
	# الخطوة القادمة هي إظهار شاشة اختيار القدرات هنا
