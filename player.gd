class_name MazePlayer
extends CharacterBody3D

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 18.0

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var pitch: float = 0.0
var input_enabled: bool = true

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
	flashlight.light_energy = 5.0
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
	setup()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := (transform.basis * Vector3(direction.x, 0.0, direction.y)).normalized()
	velocity.x = move_toward(velocity.x, wish.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, wish.z * move_speed, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
