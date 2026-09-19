class_name MazePlayer
extends CharacterBody3D

signal health_changed(current_health: float, maximum_health: float)
signal battery_changed(current_battery: float, maximum_battery: float)
signal died
signal damage_taken
signal health_restored

enum BatteryMode {
    NEVER_DRAIN = 0,
    DRAIN_AND_RECHARGE_WHEN_OFF = 1,
    DRAIN_NO_RECHARGE = 2,
}

@export var move_speed: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 18.0
@export var maximum_health: float = 100.0
@export var maximum_battery: float = 100.0
@export var attack_range: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 0.35
@export var flashlight_jitter_min_delay: float = 2.5
@export var flashlight_jitter_max_delay: float = 6.0
@export var flashlight_jitter_duration: float = 0.08
@export var flashlight_jitter_min_energy: float = 0.2

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_enabled: bool = true
var flashlight_energy: float = 5.0
var current_battery: float = 100.0
var battery_mode: int = BatteryMode.DRAIN_AND_RECHARGE_WHEN_OFF
var flashlight_jitter_time: float = 0.0
var flashlight_jitter_delay: float = 0.0
var rng := RandomNumberGenerator.new()
var pitch: float = 0.0
var input_enabled: bool = true
var current_health: float
var noise_timer: float = 0.0
var attack_timer: float = 0.0

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
	current_battery = maximum_battery
	setup()
	health_changed.emit(current_health, maximum_health)
	battery_changed.emit(current_battery, maximum_battery)
	_schedule_flashlight_jitter()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_battery_mode(mode: int) -> void:
	battery_mode = clampi(mode, BatteryMode.NEVER_DRAIN, BatteryMode.DRAIN_NO_RECHARGE)
	current_battery = maximum_battery
	flashlight_enabled = false
	flashlight.visible = false
	flashlight.light_energy = 0.0
	battery_changed.emit(current_battery, maximum_battery)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	damage_taken.emit()
	if current_health <= 0.0:
		input_enabled = false
		velocity = Vector3.ZERO
		died.emit()

func restore_health(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)
	health_restored.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and input_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and input_enabled:
		_try_attack()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if current_battery <= 0.0 and battery_mode != BatteryMode.NEVER_DRAIN:
			flashlight_enabled = false
			_update_flashlight_visibility()
			return
		flashlight_enabled = not flashlight_enabled
		_update_flashlight_visibility()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	if battery_mode == BatteryMode.NEVER_DRAIN:
		current_battery = maximum_battery
		flashlight.light_energy = flashlight_energy if flashlight_enabled else 0.0
		flashlight.visible = flashlight_enabled
		battery_changed.emit(current_battery, maximum_battery)
		return
	if flashlight_enabled and current_battery > 0.0:
		current_battery = maxf(0.0, current_battery - delta)
		battery_changed.emit(current_battery, maximum_battery)
		if current_battery <= 0.0:
			flashlight_enabled = false
			_update_flashlight_visibility()
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
	elif battery_mode == BatteryMode.DRAIN_AND_RECHARGE_WHEN_OFF and current_battery < maximum_battery:
		current_battery = minf(maximum_battery, current_battery + delta)
		battery_changed.emit(current_battery, maximum_battery)

func _update_flashlight_visibility() -> void:
	var should_be_visible := flashlight_enabled and current_battery > 0.0
	flashlight.visible = should_be_visible
	flashlight.light_energy = flashlight_energy if should_be_visible else 0.0
	if current_battery <= 0.0 and flashlight_enabled and battery_mode != BatteryMode.NEVER_DRAIN:
		flashlight_enabled = false
		flashlight.visible = false
		flashlight.light_energy = 0.0

func _schedule_flashlight_jitter() -> void:
	flashlight_jitter_delay = rng.randf_range(flashlight_jitter_min_delay, flashlight_jitter_max_delay)

func _try_attack() -> void:
	if attack_timer > 0.0 or not input_enabled:
		return
	var world := get_world_3d()
	if world == null or camera == null:
		return
	var camera_origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var best_target: Node3D = null
	var best_distance := INF
	var howlers := get_tree().get_nodes_in_group("howler")
	for candidate in howlers:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var to_target: Vector3 = candidate.global_position - camera_origin
		var distance: float = to_target.length()
		if distance > attack_range:
			continue
		var dot := forward.dot(to_target.normalized())
		if dot < 0.2:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera_origin, candidate.global_position)
		query.exclude = [self]
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") != candidate:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	if best_target == null:
		return
	attack_timer = attack_cooldown
	if best_target.has_method("apply_damage"):
		best_target.apply_damage(attack_damage)
		if best_target.has_method("emit_noise"):
			best_target.emit_noise(0.9, &"player_attack")

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := (transform.basis * Vector3(direction.x, 0.0, direction.y)).normalized()
	velocity.x = move_toward(velocity.x, wish.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, wish.z * move_speed, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
	noise_timer -= delta
	if noise_timer <= 0.0 and wish.length_squared() > 0.01:
		var noise_manager := get_tree().get_first_node_in_group("noise_manager")
		if noise_manager and noise_manager.has_method("emit_noise"):
			var movement_loudness := clampf(velocity.length() / move_speed, 0.0, 1.0) * 0.8
			noise_manager.emit_noise(global_position, movement_loudness, &"player_movement")
		noise_timer = 0.45
