class_name MazePlayer
extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal died

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 18.0
@export var maximum_health: float = 100.0
@export var flashlight_jitter_min_delay: float = 2.5
@export var flashlight_jitter_max_delay: float = 6.0
@export var flashlight_jitter_duration: float = 0.08
@export var flashlight_jitter_min_energy: float = 0.2

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_enabled: bool = true
var flashlight_energy: float = 5.0
var flashlight_jitter_time: float = 0.0
var flashlight_jitter_delay: float = 0.0
var rng := RandomNumberGenerator.new()
var pitch: float = 0.0
var input_enabled: bool = true
var current_health: float

func setup() -> void:
	add_to_group("player")
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.current = true
	camera.fov = 76.0
	head.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(1.0, 0.86, 0.63)
	flashlight_energy = 5.0
	flashlight.light_energy = flashlight_energy
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 32.0
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.0, -0.05, -0.12)
	camera.add_child(flashlight)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera.position.y = 1.58
	camera.position.z = 0.02

func _ready() -> void:
	rng.randomize()
	current_health = maximum_health
	setup()
	health_changed.emit(current_health, maximum_health)
	_schedule_flashlight_jitter()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		input_enabled = false
		velocity = Vector3.ZERO
		died.emit()

func restore_health(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		flashlight_enabled = not flashlight_enabled
		flashlight.visible = flashlight_enabled
		flashlight.light_energy = flashlight_energy
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	if not flashlight_enabled:
		return
	if flashlight_jitter_time > 0.0:
		flashlight_jitter_time -= delta
		flashlight.light_energy = flashlight_energy * rng.randf_range(flashlight_jitter_min_energy, 0.65)
		if flashlight_jitter_time <= 0.0:
			flashlight.light_energy = flashlight_energy
			_schedule_flashlight_jitter()
	else:
		flashlight_jitter_delay -= delta
		if flashlight_jitter_delay <= 0.0:
			flashlight_jitter_time = flashlight_jitter_duration

func _schedule_flashlight_jitter() -> void:
	flashlight_jitter_delay = rng.randf_range(flashlight_jitter_min_delay, flashlight_jitter_max_delay)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := (transform.basis * Vector3(direction.x, 0.0, direction.y)).normalized()
	velocity.x = move_toward(velocity.x, wish.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, wish.z * move_speed, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
