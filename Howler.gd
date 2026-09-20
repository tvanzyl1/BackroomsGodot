extends CharacterBody3D
class_name Howler

signal health_changed(current_health: float, maximum_health: float)
signal died

enum State {
	IDLE,
	PATROL,
	INVESTIGATE,
	STALK,
	ALERT,
	CHASE,
	SEARCH,
	ATTACK,
	STUNNED,
	DEAD,
}

@export_group("Health")
@export var max_health: float = 100.0
@export var respawn_delay: float = 10.0

@export_group("Movement")
@export var patrol_speed: float = 2.0
@export var investigate_speed: float = 3.0
@export var chase_speed: float = 7.0
@export var acceleration: float = 7.0
@export var turn_speed: float = 4.5
@export var attack_range: float = 1.8
@export_range(0.0, 1.0, 0.05) var attack_health_fraction: float = 0.4
@export var attack_cooldown: float = 1.5
@export var chase_cooldown: float = 4.0
@export_range(0.0, 1.0, 0.05) var aggression: float = 0.0

@export_group("Vision")
@export var vision_range: float = 18.0
@export var flashlight_vision_range: float = 27.0
@export var vision_angle: float = 110.0
@export var flashlight_beam_detection_range: float = 24.0
@export var vision_check_interval: float = 0.2
@export var player_lose_sight_threshold: float = 0.2

@export_group("Hearing")
@export var hearing_range: float = 32.0
@export var minimum_heard_loudness: float = 0.12
@export var investigate_loudness: float = 0.28
@export var stalk_loudness: float = 0.65

@export_group("Patrol / Idle")
@export var patrol_radius: float = 20.0
@export var idle_min_duration: float = 3.0
@export var idle_max_duration: float = 10.0
@export var patrol_point_min_delay: float = 1.5
@export var patrol_point_max_delay: float = 4.5

@export_group("Investigation")
@export var investigate_timeout: float = 7.0
@export var search_duration: float = 10.0
@export var investigation_look_time: float = 2.0

@export_group("Stalking")
@export var stalk_min_duration: float = 5.0
@export var stalk_max_duration: float = 20.0
@export var stalking_distance: float = 4.5
@export var stalking_pause_chance: float = 0.28

@export_group("Alert / Audio")
@export var howl_delay_min: float = 0.5
@export var howl_delay_max: float = 1.5
@export var idle_breath_interval_min: float = 1.5
@export var idle_breath_interval_max: float = 5.5
@export var howl_cooldown: float = 8.0
@export var chase_vocal_interval: float = 2.0

@export_group("Debug")
@export var debug_enabled: bool = true
@export var show_state_name: bool = false

@export_group("LimboAI")
@export var use_limbo_ai: bool = true

var current_state: State = State.IDLE
var state_name: String = "IDLE"
var current_health: float = 100.0
var respawn_timer: float = 0.0
var is_dead: bool = false

var player: Node3D
var navigation_agent: NavigationAgent3D
var model_root: Node3D
var collision_shape: CollisionShape3D
var vision_origin: Marker3D
var attack_origin: Marker3D
var audio_node: Node
var idle_audio: AudioStreamPlayer3D
var howl_audio: AudioStreamPlayer3D
var chase_audio: AudioStreamPlayer3D
var attack_audio: AudioStreamPlayer3D
var animation_player: AnimationPlayer
var debug_visuals: Node3D
var monster_skeleton: Skeleton3D
var monster_bones: Dictionary = {}
var monster_rest_rotations: Dictionary = {}
var procedural_animation_time: float = 0.0

var rng := RandomNumberGenerator.new()
var last_vision_check: float = 0.0
var idle_timer: float = 0.0
var patrol_point_timer: float = 0.0
var investigate_timer: float = 0.0
var search_timer: float = 0.0
var stalk_timer: float = 0.0
var alert_timer: float = 0.0
var attack_timer: float = 0.0
var stun_timer: float = 0.0
var last_howl_time: float = -999.0
var last_breath_time: float = 0.0
var last_path_update: float = 0.0
var last_known_player_position: Vector3 = Vector3.ZERO
var player_detected: bool = false
var player_in_sight: bool = false
var pending_attack: bool = false
var target_position: Vector3 = Vector3.ZERO
var _target_position: Vector3 = Vector3.ZERO
var has_valid_patrol_target: bool = false
var has_player_target: bool = false
var current_target: Vector3 = Vector3.ZERO
var navigation_goal: Vector3 = Vector3.ZERO

var _noise_manager: Node
var _attack_window_open: bool = false
var _last_attack_time: float = -999.0
var _noise_position: Vector3 = Vector3.ZERO
var _can_howl: bool = true
var _search_turn_dir: float = 1.0
var _limbo_ai_active: bool = false

func _ready() -> void:
	rng.randomize()
	current_health = max_health
	_setup_children()
	_set_state(State.IDLE)
	_setup_noise_manager()
	_setup_limbo_ai()
	_apply_default_model()
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if navigation_agent:
		navigation_agent.target_position = global_position
	
func _process(delta: float) -> void:
	if current_state == State.DEAD:
		respawn_timer += delta
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		player = null
		return
	if _limbo_ai_active:
		return
	_update_state_logic(delta)
	_update_navigation(delta)
	_update_audio(delta)
	_update_debug_visuals()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	_handle_movement(delta)
	_update_model_animation()
	_update_vision()
	_handle_noise_reactions()

func _setup_limbo_ai() -> void:
	if not use_limbo_ai or not ClassDB.class_exists("BTPlayer"):
		return
	var bt_player := BTPlayer.new()
	bt_player.name = "LimboAI"
	bt_player.update_mode = BTPlayer.PHYSICS
	var behavior_tree := BehaviorTree.new()
	var task_script := load("res://HowlerLimboTask.gd")
	if task_script == null:
		return
	behavior_tree.set_root_task(task_script.new())
	bt_player.behavior_tree = behavior_tree
	var scene_root := get_tree().current_scene
	if scene_root != null:
		bt_player.set_scene_root_hint(scene_root)
	add_child(bt_player)
	_limbo_ai_active = true

func _limbo_tick(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		player = null
		return
	_update_state_logic(delta)
	_update_navigation(delta)
	_update_audio(delta)
	_update_debug_visuals()

func _setup_children() -> void:
	collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision_shape.shape = capsule
	collision_shape.position.y = 0.9

	model_root = get_node_or_null("ModelRoot")
	if model_root == null:
		model_root = Node3D.new()
		model_root.name = "ModelRoot"
		add_child(model_root)
	if model_root.get_child_count() == 0:
		var placeholder := MeshInstance3D.new()
		placeholder.name = "PlaceholderBody"
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.45
		body_mesh.height = 1.8
		placeholder.mesh = body_mesh
		placeholder.position.y = 1.0
		model_root.add_child(placeholder)
	_setup_procedural_animation()

	navigation_agent = get_node_or_null("NavigationAgent3D")
	if navigation_agent == null:
		navigation_agent = NavigationAgent3D.new()
		navigation_agent.name = "NavigationAgent3D"
		add_child(navigation_agent)
	navigation_agent.radius = 0.42
	navigation_agent.neighbor_distance = 10.0
	navigation_agent.time_horizon = 5.0
	navigation_agent.max_speed = chase_speed
	navigation_agent.path_desired_distance = 0.35
	navigation_agent.target_desired_distance = 0.7

	vision_origin = get_node_or_null("VisionOrigin")
	if vision_origin == null:
		vision_origin = Marker3D.new()
		vision_origin.name = "VisionOrigin"
		add_child(vision_origin)
	vision_origin.position = Vector3(0.0, 1.6, 0.0)

	attack_origin = get_node_or_null("AttackOrigin")
	if attack_origin == null:
		attack_origin = Marker3D.new()
		attack_origin.name = "AttackOrigin"
		add_child(attack_origin)
	attack_origin.position = Vector3(0.0, 1.2, 0.8)

	audio_node = get_node_or_null("Audio")
	if audio_node == null:
		audio_node = Node.new()
		audio_node.name = "Audio"
		add_child(audio_node)

	idle_audio = audio_node.get_node_or_null("IdleAudio")
	if idle_audio == null:
		idle_audio = AudioStreamPlayer3D.new()
		idle_audio.name = "IdleAudio"
		audio_node.add_child(idle_audio)

	howl_audio = audio_node.get_node_or_null("HowlAudio")
	if howl_audio == null:
		howl_audio = AudioStreamPlayer3D.new()
		howl_audio.name = "HowlAudio"
		audio_node.add_child(howl_audio)

	chase_audio = audio_node.get_node_or_null("ChaseAudio")
	if chase_audio == null:
		chase_audio = AudioStreamPlayer3D.new()
		chase_audio.name = "ChaseAudio"
		audio_node.add_child(chase_audio)

	attack_audio = audio_node.get_node_or_null("AttackAudio")
	if attack_audio == null:
		attack_audio = AudioStreamPlayer3D.new()
		attack_audio.name = "AttackAudio"
		audio_node.add_child(attack_audio)

	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)

	debug_visuals = get_node_or_null("DebugVisuals")
	if debug_visuals == null:
		debug_visuals = Node3D.new()
		debug_visuals.name = "DebugVisuals"
		add_child(debug_visuals)

func _apply_default_model() -> void:
	if model_root == null:
		return
	if model_root.get_child_count() > 0:
		return
	var placeholder := MeshInstance3D.new()
	placeholder.name = "PlaceholderBody"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = 1.8
	placeholder.mesh = body_mesh
	placeholder.position.y = 1.0
	model_root.add_child(placeholder)

func _setup_procedural_animation() -> void:
	monster_skeleton = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if monster_skeleton == null:
		return
	for bone_index in monster_skeleton.get_bone_count():
		var bone_name := StringName(monster_skeleton.get_bone_name(bone_index))
		monster_bones[bone_name] = bone_index
		monster_rest_rotations[bone_name] = monster_skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()

func _update_procedural_animation(delta: float) -> void:
	if monster_skeleton == null:
		return
	procedural_animation_time += delta
	var movement_speed := Vector2(velocity.x, velocity.z).length()
	var walking := movement_speed > 0.1
	var cycle_speed := 4.0 + movement_speed * 0.8
	var cycle := procedural_animation_time * cycle_speed
	var swing := sin(cycle) if walking else sin(procedural_animation_time * 1.5) * 0.12
	var leg_swing := swing * 0.55 if walking else swing * 0.25
	_set_bone_rotation(&"upperarm_l", Vector3.FORWARD, 1.15 + swing * 0.15)
	_set_bone_rotation(&"upperarm_r", Vector3.FORWARD, -1.15 - swing * 0.15)
	_set_bone_rotation(&"lowerarm_l", Vector3.FORWARD, -0.25)
	_set_bone_rotation(&"lowerarm_r", Vector3.FORWARD, 0.25)
	_set_bone_rotation(&"thigh_l", Vector3.RIGHT, leg_swing)
	_set_bone_rotation(&"thigh_r", Vector3.RIGHT, -leg_swing)
	_set_bone_rotation(&"calf_l", Vector3.RIGHT, max(0.0, -leg_swing) * 0.7)
	_set_bone_rotation(&"calf_r", Vector3.RIGHT, max(0.0, leg_swing) * 0.7)
	_set_bone_rotation(&"spine_02", Vector3.RIGHT, sin(procedural_animation_time * 1.5) * 0.04)

func _set_bone_rotation(bone_name: StringName, axis: Vector3, angle: float) -> void:
	if not monster_bones.has(bone_name):
		return
	var bone_index: int = monster_bones[bone_name]
	var rest_rotation: Quaternion = monster_rest_rotations[bone_name]
	monster_skeleton.set_bone_pose_rotation(bone_index, rest_rotation * Quaternion(axis, angle))

func _setup_noise_manager() -> void:
	var existing := get_tree().get_first_node_in_group("noise_manager")
	if existing:
		if existing.has_method("get_recent_noise") and existing.has_method("emit_noise"):
			_noise_manager = existing
		else:
			existing.remove_from_group("noise_manager")
			_noise_manager = NoiseManager.new()
			_noise_manager.name = "NoiseManager"
			_noise_manager.add_to_group("noise_manager")
			get_tree().root.call_deferred("add_child", _noise_manager)
		if _noise_manager.has_signal("noise_emitted") and not _noise_manager.is_connected("noise_emitted", _on_noise_emitted):
			_noise_manager.noise_emitted.connect(_on_noise_emitted)
		return
	var manager: Node = NoiseManager.new()
	manager.name = "NoiseManager"
	manager.add_to_group("noise_manager")
	_noise_manager = manager
	if get_tree() and get_tree().root:
		get_tree().root.call_deferred("add_child", _noise_manager)
	if _noise_manager.has_signal("noise_emitted") and not _noise_manager.is_connected("noise_emitted", _on_noise_emitted):
		_noise_manager.noise_emitted.connect(_on_noise_emitted)

func _on_noise_emitted(position: Vector3, loudness: float, source: StringName) -> void:
	if loudness <= 0.0:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	var distance := global_position.distance_to(position)
	var perceived_loudness := loudness * clampf(1.0 - distance / hearing_range, 0.0, 1.0)
	if perceived_loudness >= minimum_heard_loudness:
		_noise_position = position
		last_known_player_position = position if source == &"player_movement" else last_known_player_position
		_target_position = position
		if current_state in [State.IDLE, State.PATROL, State.SEARCH]:
			if perceived_loudness >= stalk_loudness and rng.randf() < aggression * 0.8:
				_set_state(State.CHASE)
			else:
				_set_state(State.STALK if perceived_loudness >= stalk_loudness else State.INVESTIGATE)
			investigate_timer = investigate_timeout

func _update_state_logic(delta: float) -> void:
	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.PATROL:
			_handle_patrol(delta)
		State.INVESTIGATE:
			_handle_investigate(delta)
		State.STALK:
			_handle_stalk(delta)
		State.ALERT:
			_handle_alert(delta)
		State.CHASE:
			_handle_chase(delta)
		State.SEARCH:
			_handle_search(delta)
		State.ATTACK:
			_handle_attack(delta)
		State.STUNNED:
			_handle_stunned(delta)
		State.DEAD:
			return

func _handle_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		if rng.randf() < 0.75:
			_set_state(State.PATROL)
		else:
			idle_timer = rng.randf_range(idle_min_duration, idle_max_duration)
			if rng.randf() < 0.35:
				_emit_howl_if_possible("idle")
				return
		if rng.randf() < 0.2:
			_emit_idle_sound()
		return
	if Time.get_ticks_msec() - last_breath_time > rng.randi_range(1500, 5000):
		_emit_idle_sound()
		last_breath_time = Time.get_ticks_msec()
	if rng.randf() < 0.3 * delta:
		rotation.y += rng.randf_range(-0.35, 0.35)
	if _can_see_player():
		_set_state(State.ALERT)

func _handle_patrol(delta: float) -> void:
	patrol_point_timer -= delta
	if not has_valid_patrol_target or patrol_point_timer <= 0.0:
		_choose_patrol_target()
		patrol_point_timer = rng.randf_range(patrol_point_min_delay, patrol_point_max_delay)
	if has_valid_patrol_target:
		_move_toward_position(target_position, patrol_speed, delta)
		if global_position.distance_to(target_position) < 1.5:
			has_valid_patrol_target = false
		if _can_see_player():
			_set_state(State.ALERT)
		if rng.randf() < 0.05 * delta:
			_emit_idle_sound()
	if _noise_position != Vector3.ZERO and global_position.distance_to(_noise_position) < vision_range * 1.5:
		_set_state(State.INVESTIGATE)

func _handle_investigate(delta: float) -> void:
	investigate_timer -= delta
	if player and _can_see_player():
		_set_state(State.ALERT)
		return
	_move_toward_position(_noise_position, investigate_speed, delta)
	if global_position.distance_to(_noise_position) < 1.5:
		_set_state(State.SEARCH)
		search_timer = search_duration
		return
	if investigate_timer <= 0.0:
		_set_state(State.PATROL)
		_noise_position = Vector3.ZERO
		if rng.randf() < 0.6:
			_emit_howl_if_possible("investigate")

func _handle_stalk(delta: float) -> void:
	stalk_timer -= delta
	if player and _can_see_player():
		_set_state(State.ALERT)
		return
	if stalk_timer <= 0.0:
		var roll := rng.randf()
		var chase_threshold := 0.3 + aggression * 0.55
		if roll < (1.0 - chase_threshold) * 0.5:
			_set_state(State.PATROL)
		elif roll < 1.0 - chase_threshold:
			_set_state(State.SEARCH)
		else:
			_emit_howl_if_possible("stalk")
			_set_state(State.CHASE)
		return
	var offset := Vector3.ZERO
	if player:
		offset = (global_position - player.global_position).normalized()
		var side := Vector3(-offset.z, 0.0, offset.x)
		var preferred := player.global_position + (offset * stalking_distance) + (side * rng.randf_range(-2.0, 2.0))
		preferred.y = global_position.y
		_move_toward_position(preferred, patrol_speed * 1.2, delta)
		if rng.randf() < 0.012:
			_emit_idle_sound()
	if rng.randf() < stalking_pause_chance * delta:
		velocity = Vector3.ZERO

func _handle_alert(delta: float) -> void:
	if player and _can_see_player():
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		alert_timer -= delta
		if alert_timer <= 0.0:
			_emit_howl_if_possible("alert")
			_set_state(State.CHASE)
		else:
			velocity = Vector3.ZERO
		return
	_set_state(State.SEARCH)
	search_timer = search_duration
	last_known_player_position = player.global_position if player else last_known_player_position

func _handle_chase(delta: float) -> void:
	if player == null:
		_set_state(State.PATROL)
		return
	last_known_player_position = player.global_position
	if _can_see_player() and _distance_to_player() <= attack_range:
		_set_state(State.ATTACK)
		return
	var target := player.global_position
	if _distance_to_player() > 10.0 and not _can_see_player():
		target = last_known_player_position
	_move_toward_position(target, chase_speed, delta, true)
	if rng.randf() < 0.08 * delta:
		chase_audio.play()
	if _can_see_player() and rng.randf() < 0.05:
		_set_state(State.STALK)
		stalk_timer = rng.randf_range(stalk_min_duration, stalk_max_duration)

func _handle_search(delta: float) -> void:
	search_timer -= delta
	if player and _can_see_player():
		_set_state(State.ALERT)
		return
	var search_target: Vector3 = global_position + Vector3(cos(search_timer * 0.6 + rotation.y), 0.0, sin(search_timer * 0.6 + rotation.y)) * 2.5 * _search_turn_dir
	_move_toward_position(search_target, investigate_speed * 0.8, delta)
	rotation.y += 0.9 * delta * _search_turn_dir
	if search_timer <= 0.0:
		_set_state(State.PATROL)
		_noise_position = Vector3.ZERO
		_search_turn_dir *= -1.0

func _handle_attack(delta: float) -> void:
	if player == null:
		_set_state(State.PATROL)
		return
	var direction := (player.global_position - global_position)
	direction.y = 0.0
	if direction.length_squared() > 0.0:
		look_at(player.global_position, Vector3.UP)
	if Time.get_ticks_msec() - _last_attack_time < attack_cooldown * 1000.0:
		velocity = Vector3.ZERO
		return
	if not _attack_window_open:
		attack_audio.play()
		_attack_window_open = true
		_last_attack_time = Time.get_ticks_msec()
		if is_instance_valid(player) and player.has_method("take_damage"):
			var maximum_health := float(player.get("maximum_health"))
			player.take_damage(maximum_health * attack_health_fraction)
		_set_state(State.CHASE)
		_attack_window_open = false

func _handle_stunned(delta: float) -> void:
	stun_timer -= delta
	velocity = Vector3.ZERO
	if stun_timer <= 0.0:
		_set_state(State.PATROL)

func _update_navigation(delta: float) -> void:
	if navigation_agent == null:
		return
	if current_state in [State.CHASE, State.PATROL, State.INVESTIGATE, State.SEARCH, State.STALK]:
		if navigation_goal != Vector3.ZERO and navigation_goal.distance_to(global_position) > 0.1:
			var next_point := navigation_agent.get_next_path_position()
			if next_point != Vector3.ZERO:
				current_target = next_point

func _handle_movement(delta: float) -> void:
	var target_velocity := Vector3.ZERO
	if velocity.length() > 0.01:
		target_velocity = velocity
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	if velocity.length() > 0.05:
		move_and_slide()
	else:
		velocity = Vector3.ZERO
	if current_state == State.CHASE and player:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

func _move_toward_position(goal: Vector3, speed: float, delta: float, is_chase: bool = false) -> void:
	if goal == Vector3.ZERO:
		return
	navigation_goal = goal
	if navigation_agent:
		navigation_agent.target_position = goal
	var direction := goal - global_position
	direction.y = 0.0
	var distance := direction.length()
	if navigation_agent and navigation_agent.get_final_position() != Vector3.ZERO:
		var next_point := navigation_agent.get_next_path_position()
		if next_point != Vector3.ZERO:
			direction = next_point - global_position
			direction.y = 0.0
			distance = direction.length()
	if distance > 0.01:
		direction = direction.normalized()
		var target_angle := Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		velocity.y = 0.0
		if distance < 1.2 and not is_chase:
			velocity *= 0.35
	else:
		velocity = Vector3.ZERO

func _choose_patrol_target() -> void:
	has_valid_patrol_target = false
	var center := global_position
	for attempt in range(12):
		var offset := Vector3(
			rng.randf_range(-patrol_radius, patrol_radius),
			0.0,
			rng.randf_range(-patrol_radius, patrol_radius)
		)
		var candidate := center + offset
		candidate.y = global_position.y
		if _is_navmesh_valid(candidate):
			target_position = candidate
			has_valid_patrol_target = true
			current_target = candidate
			return
	if current_state != State.DEAD:
		target_position = global_position
		has_valid_patrol_target = false

func _is_navmesh_valid(candidate: Vector3) -> bool:
	if candidate.distance_to(global_position) > patrol_radius * 1.5:
		return false
	return true

func _update_vision() -> void:
	if player == null:
		return
	if Time.get_ticks_msec() - last_vision_check < vision_check_interval * 1000.0:
		return
	last_vision_check = Time.get_ticks_msec()
	player_in_sight = _can_see_player()
	if player_in_sight:
		last_known_player_position = player.global_position
		if current_state in [State.IDLE, State.PATROL, State.SEARCH, State.INVESTIGATE]:
			_set_state(State.ALERT)
		elif current_state == State.CHASE:
			last_known_player_position = player.global_position
	elif current_state in [State.IDLE, State.PATROL, State.SEARCH, State.INVESTIGATE] and _can_see_flashlight():
		last_known_player_position = player.global_position
		_noise_position = player.global_position
		investigate_timer = investigate_timeout
		_set_state(State.INVESTIGATE)

func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_player: Vector3 = player.global_position - vision_origin.global_position
	var distance := to_player.length()
	var current_vision_range := flashlight_vision_range if _is_player_flashlight_active() else vision_range
	if distance > current_vision_range:
		return false
	var forward := -transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > vision_angle * 0.5:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(vision_origin.global_position, player.global_position)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	if result.size() > 0 and result.get("collider") != player:
		return false
	return true

func _can_see_flashlight() -> bool:
	if not _is_player_flashlight_active() or player == null or not is_instance_valid(player):
		return false
	var camera := player.get("camera") as Camera3D
	if camera == null:
		return false
	var to_howler := vision_origin.global_position - camera.global_position
	var distance := to_howler.length()
	if distance > flashlight_beam_detection_range:
		return false
	var beam_forward := -camera.global_transform.basis.z
	var beam_angle := deg_to_rad(16.0)
	var beam_dot := beam_forward.dot(to_howler.normalized())
	if beam_dot < cos(beam_angle):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, vision_origin.global_position)
	query.exclude = [self, player]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider := result.get("collider") as Node
	return collider == self or (collider != null and is_ancestor_of(collider))

func _is_player_flashlight_active() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return bool(player.get("flashlight_enabled")) and float(player.get("current_battery")) > 0.0

func _distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

func _emit_idle_sound() -> void:
	if idle_audio and idle_audio.stream:
		idle_audio.play()
	elif idle_audio:
		idle_audio.pitch_scale = rng.randf_range(0.7, 1.1)
		idle_audio.play()

func _emit_howl_if_possible(id: String) -> void:
	if Time.get_ticks_msec() - last_howl_time < howl_cooldown * 1000.0:
		return
	if howl_audio == null:
		return
	last_howl_time = Time.get_ticks_msec()
	howl_audio.pitch_scale = rng.randf_range(0.8, 1.25)
	howl_audio.play()
	_can_howl = true
	if animation_player and animation_player.has_animation("Howl"):
		animation_player.play("Howl")
	if id == "alert":
		alert_timer = rng.randf_range(howl_delay_min, howl_delay_max)

func _handle_noise_reactions() -> void:
	if _noise_manager == null or not _noise_manager.has_method("get_recent_noise"):
		_setup_noise_manager()
	if _noise_manager == null or not _noise_manager.has_method("get_recent_noise"):
		return
	var noises: Array = _noise_manager.get_recent_noise(global_position, hearing_range, 5000)
	if noises.is_empty():
		return
	var loudest: Dictionary = {}
	var best_loudness := 0.0
	for noise in noises:
		if typeof(noise) != TYPE_DICTIONARY:
			continue
		var perceived_loudness := float(noise.get("perceived_loudness", noise["loudness"]))
		if perceived_loudness > best_loudness:
			best_loudness = perceived_loudness
			loudest = noise
	if loudest.is_empty():
		return
	if best_loudness < minimum_heard_loudness:
		return
	_noise_position = Vector3(loudest["position"])
	if StringName(loudest.get("source", &"")) == &"player_movement":
		last_known_player_position = _noise_position
	if current_state in [State.IDLE, State.PATROL, State.SEARCH]:
		if best_loudness >= stalk_loudness and rng.randf() < aggression * 0.8:
			_set_state(State.CHASE)
		else:
			_set_state(State.STALK if best_loudness >= stalk_loudness else State.INVESTIGATE)
		investigate_timer = investigate_timeout
		_target_position = _noise_position

func _update_audio(delta: float) -> void:
	if chase_audio and current_state == State.CHASE:
		chase_audio.volume_db = 2.0
	if idle_audio and current_state != State.CHASE:
		idle_audio.volume_db = -12.0
	if attack_audio and current_state == State.ATTACK:
		attack_audio.volume_db = 4.0

func _update_debug_visuals() -> void:
	if not debug_enabled:
		return
	for child in debug_visuals.get_children():
		child.queue_free()
	if show_state_name:
		var label := Label3D.new()
		label.text = state_name
		label.position = Vector3(0.0, 2.6, 0.0)
		label.modulate = Color(1.0, 0.2, 0.2)
		debug_visuals.add_child(label)
	var ring := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	ring.mesh = sphere
	ring.position = Vector3(0.0, 0.2, 0.0)
	ring.material_override = StandardMaterial3D.new()
	ring.material_override.albedo_color = Color(1.0, 0.0, 0.0)
	debug_visuals.add_child(ring)

func _update_model_animation() -> void:
	if animation_player == null or not animation_player.has_animation("Walk"):
		return
	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if is_moving:
		if animation_player.current_animation != "Walk":
			animation_player.play("Walk")
	elif animation_player.current_animation == "Walk":
		animation_player.stop()

func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_name = State.keys()[new_state]
	match new_state:
		State.IDLE:
			idle_timer = rng.randf_range(idle_min_duration, idle_max_duration)
		State.PATROL:
			has_valid_patrol_target = false
			patrol_point_timer = 0.0
		State.INVESTIGATE:
			investigate_timer = investigate_timeout
		State.STALK:
			var stalk_scale := lerpf(1.0, 0.35, aggression)
			stalk_timer = rng.randf_range(stalk_min_duration, stalk_max_duration) * stalk_scale
		State.ALERT:
			alert_timer = rng.randf_range(howl_delay_min, howl_delay_max)
		State.CHASE:
			if player and is_instance_valid(player):
				last_known_player_position = player.global_position
				current_target = last_known_player_position
		State.SEARCH:
			search_timer = search_duration
			_search_turn_dir = [-1.0, 1.0][randi() % 2]
		State.ATTACK:
			_attack_window_open = false
		State.STUNNED:
			stun_timer = 0.1
		State.DEAD:
			is_dead = true
			velocity = Vector3.ZERO
			model_root.visible = false
			collision_shape.set_deferred("disabled", true)
			set_collision_layer(0)
			set_collision_mask(0)
			for child in audio_node.get_children():
				if child is AudioStreamPlayer3D:
					child.stop()
			if is_instance_valid(animation_player):
				animation_player.stop()

func set_player_reference(player_ref: Node3D) -> void:
	player = player_ref
	if player != null:
		last_known_player_position = player.global_position

func apply_damage(amount: float) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		current_health = 0.0
		is_dead = true
		respawn_timer = 0.0
		_set_state(State.DEAD)
		died.emit()
		return
	if current_state != State.STUNNED:
		_set_state(State.STUNNED)
	velocity = Vector3.ZERO

func emit_noise(loudness: float, source: StringName = "") -> void:
	if _noise_manager == null:
		_setup_noise_manager()
	_noise_manager.emit_noise(global_position, loudness, source)
