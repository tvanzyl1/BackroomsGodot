extends Node3D

const PLAYER_SCRIPT: Script = preload("res://player.gd")
const HEALTH_ORB_SCRIPT: Script = preload("res://HealthOrb.gd")
const FEEDBACK_OVERLAY_SCRIPT: Script = preload("res://FeedbackOverlay.gd")
const BASE_MAZE_SIZE: int = 17
const CELL_SIZE: float = 3.2
const WALL_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.18
const HEALTH_ORB_COUNT: int = 3
const HEALTH_ORB_AMOUNT: float = 25.0
const HOWLER_BASE_HEALTH: float = 100.0

var maze: Array[Array] = []
var maze_root: Node3D
var howler: Node3D
var player: MazePlayer
var rng := RandomNumberGenerator.new()
var generation: int = 0
var level: int = 1
var maze_size: int = BASE_MAZE_SIZE
var status_label: Label
var seed_label: Label
var health_label: Label
var health_bar: ProgressBar
var battery_label: Label
var battery_bar: ProgressBar
var howler_health_label: Label
var howler_health_bar: ProgressBar
var feedback_overlay: Control
var death_overlay: ColorRect
var death_message: Label
var end_overlay: ColorRect
var end_message: Label
var new_game_button: Button
var start_overlay: ColorRect
var start_message: Label
var start_button: Button
var selected_battery_mode: int = MazePlayer.BatteryMode.DRAIN_AND_RECHARGE_WHEN_OFF
var battery_mode_buttons: Array[Button] = []
var quit_dialog: ConfirmationDialog
var new_game_dialog: ConfirmationDialog
var roof_lights: Array[Dictionary] = []
var noise_manager: Node
var game_finished: bool = false
var game_over: bool = false
var game_started: bool = false
var death_time: float = 0.0
var exit_position: Vector3 = Vector3.ZERO

var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var ceiling_material: StandardMaterial3D
var exit_material: StandardMaterial3D

func _ready() -> void:
	rng.randomize()
	_create_materials()
	_create_hud()
	noise_manager = NoiseManager.new()
	noise_manager.name = "NoiseManager"
	noise_manager.add_to_group("noise_manager")
	add_child(noise_manager)
	new_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_game"):
		_request_new_game()
		return
	if not game_started and event is InputEventKey and event.pressed:
		_start_game()
		return
	if event.is_action_pressed("quit_game") and not quit_dialog.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit_dialog.popup_centered()
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func new_game(reset_level: bool = true, auto_start: bool = false) -> void:
	if reset_level:
		level = 1
	maze_size = BASE_MAZE_SIZE + (level - 1) * 2
	generation += 1
	game_finished = false
	game_over = false
	game_started = false
	death_time = 0.0
	if is_instance_valid(howler):
		howler.free()
	howler = null
	if is_instance_valid(player):
		player.free()
	player = null
	if maze_root:
		maze_root.queue_free()
	maze_root = Node3D.new()
	maze_root.name = "GeneratedMaze"
	add_child(maze_root)
	_generate_maze()
	_build_maze()
	_spawn_player()
	if is_instance_valid(player):
		player.input_enabled = false
	if is_instance_valid(howler):
		howler.set_process(false)
		howler.set_physics_process(false)
	death_overlay.visible = false
	death_message.visible = false
	end_overlay.visible = false
	if is_instance_valid(start_overlay):
		start_overlay.visible = not auto_start
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	seed_label.text = "LEVEL %02d  //  SECTOR %02d  //  SEED %08d" % [level, generation, rng.seed]
	status_label.text = "Find the way out"
	if auto_start:
		_start_game()

func _request_new_game() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	new_game_dialog.popup_centered()

func _process(delta: float) -> void:
	if not game_finished and is_instance_valid(player) and player.global_position.distance_to(exit_position) < CELL_SIZE * 0.42:
		_complete_maze()
	if is_instance_valid(howler):
		if howler.get("is_dead") == true:
			if is_instance_valid(howler_health_bar):
				howler_health_bar.visible = false
			if is_instance_valid(howler_health_label):
				howler_health_label.text = ""
			var elapsed := float(howler.get("respawn_timer")) + delta
			howler.set("respawn_timer", elapsed)
			if elapsed >= float(howler.get("respawn_delay")):
				howler.queue_free()
				howler = null
				_spawn_howler()
		else:
			var player_can_see_howler := _player_can_see_howler(howler)
			if player_can_see_howler:
				if is_instance_valid(howler_health_bar):
					howler_health_bar.visible = true
					howler_health_bar.max_value = float(howler.get("max_health"))
					howler_health_bar.value = float(howler.get("current_health"))
				if is_instance_valid(howler_health_label):
					howler_health_label.text = "HOWLER  %d%%" % roundi((float(howler.get("current_health")) / float(howler.get("max_health"))) * 100.0)
			else:
				if is_instance_valid(howler_health_bar):
					howler_health_bar.visible = false
				if is_instance_valid(howler_health_label):
					howler_health_label.text = ""
	if game_over and is_instance_valid(player):
		death_time += delta
		player.head.rotation.z = lerp_angle(player.head.rotation.z, -1.35, minf(delta * 2.5, 1.0))
		player.camera.position.y = lerpf(player.camera.position.y, 0.35, minf(delta * 1.8, 1.0))
	for state in roof_lights:
		if state.broken:
			continue
		state.next_flicker -= delta
		if state.flicker_left > 0.0:
			state.flicker_left -= delta
			state.pulse_timer -= delta
			if state.pulse_timer <= 0.0:
				state.light.light_energy = state.base_energy * rng.randf_range(0.12, 0.9)
				state.pulse_timer = rng.randf_range(0.035, 0.11)
			if state.flicker_left <= 0.0:
				state.light.light_energy = state.base_energy
				state.next_flicker = rng.randf_range(3.0, 10.0)
		elif state.next_flicker <= 0.0:
			state.flicker_left = rng.randf_range(0.16, 0.7)
			state.pulse_timer = 0.0

func _generate_maze() -> void:
	maze.clear()
	for z in range(maze_size):
		var row: Array = []
		for x in range(maze_size):
			row.append(true)
		maze.append(row)
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	maze[1][1] = false
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for direction in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var next: Vector2i = current + direction
			if next.x > 0 and next.x < maze_size - 1 and next.y > 0 and next.y < maze_size - 1 and maze[next.y][next.x]:
				options.append(next)
		if options.is_empty():
			stack.pop_back()
		else:
			var next: Vector2i = options[rng.randi_range(0, options.size() - 1)]
			maze[current.y + (next.y - current.y) / 2][current.x + (next.x - current.x) / 2] = false
			maze[next.y][next.x] = false
			stack.append(next)
	# Open a few unsettling sightlines so the maze feels less grid-perfect.
	for index in range(7):
		var x := rng.randi_range(1, maze_size - 2)
		var z := rng.randi_range(1, maze_size - 2)
		if (x + z) % 2 == 1:
			maze[z][x] = false
	_add_oversized_rooms()

func _add_oversized_rooms() -> void:
	var room_candidates: Array[Vector2i] = []
	for z in range(1, maze_size - 1):
		for x in range(1, maze_size - 1):
			if not maze[z][x]:
				room_candidates.append(Vector2i(x, z))
	room_candidates.shuffle()
	var room_count := rng.randi_range(2, 5)
	for room_index in range(room_count):
		if room_candidates.is_empty():
			break
		var center: Vector2i = room_candidates.pop_back()
		if center == Vector2i(1, 1) or center == _exit_cell():
			continue
		var half_width := rng.randi_range(1, 3)
		var half_height := rng.randi_range(1, 3)
		var min_x := maxi(1, center.x - half_width)
		var max_x := mini(maze_size - 2, center.x + half_width)
		var min_z := maxi(1, center.y - half_height)
		var max_z := mini(maze_size - 2, center.y + half_height)
		for z in range(min_z, max_z + 1):
			for x in range(min_x, max_x + 1):
				if Vector2i(x, z) != Vector2i(1, 1) and Vector2i(x, z) != _exit_cell():
					maze[z][x] = false

func _build_maze() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	maze_root.add_child(floor_body)
	_add_box(floor_body, Vector3(maze_size * CELL_SIZE, 0.0, maze_size * CELL_SIZE), Vector3(0.0, -0.12, 0.0), floor_material)
	_add_navigation_region()
	var ceiling_body := StaticBody3D.new()
	ceiling_body.name = "Ceiling"
	maze_root.add_child(ceiling_body)
	_add_box(ceiling_body, Vector3(maze_size * CELL_SIZE, 0.18, maze_size * CELL_SIZE), Vector3(0.0, WALL_HEIGHT, 0.0), ceiling_material)
	for z in range(maze_size):
		for x in range(maze_size):
			if maze[z][x]:
				var wall_body := StaticBody3D.new()
				wall_body.name = "Wall_%d_%d" % [x, z]
				maze_root.add_child(wall_body)
				_add_box(wall_body, Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE), _cell_position(x, z) + Vector3(0.0, WALL_HEIGHT / 2.0, 0.0), wall_material)
	var exit_marker := MeshInstance3D.new()
	exit_marker.name = "ExitLight"
	var exit_mesh := CylinderMesh.new()
	exit_mesh.top_radius = 0.18
	exit_mesh.bottom_radius = 0.18
	exit_mesh.height = 0.12
	exit_marker.mesh = exit_mesh
	var exit_cell := _exit_cell()
	exit_position = _cell_position(exit_cell.x, exit_cell.y)
	exit_marker.position = exit_position + Vector3(0.0, 0.3, 0.0)
	exit_marker.material_override = exit_material
	maze_root.add_child(exit_marker)
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Color(0.95, 0.35, 0.08)
	exit_light.light_energy = 2.2
	exit_light.omni_range = 4.5
	exit_light.position = exit_marker.position + Vector3(0.0, 1.0, 0.0)
	maze_root.add_child(exit_light)
	_spawn_health_orbs()
	_add_lights()

func _add_navigation_region() -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "MazeNavigation"
	var navigation_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	var vertex_indices: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	var half_cell := CELL_SIZE * 0.5
	for z in range(maze_size):
		for x in range(maze_size):
			if maze[z][x]:
				continue
			var center := _cell_position(x, z) + Vector3(0.0, 0.02, 0.0)
			var cell_corners: Array[Vector2i] = [
				Vector2i(x, z),
				Vector2i(x, z + 1),
				Vector2i(x + 1, z + 1),
				Vector2i(x + 1, z),
			]
			var polygon := PackedInt32Array()
			for corner in cell_corners:
				if not vertex_indices.has(corner):
					var corner_position := _cell_position(corner.x, corner.y)
					vertex_indices[corner] = vertices.size()
					vertices.append(corner_position + Vector3(-half_cell, 0.02, -half_cell))
				polygon.append(vertex_indices[corner])
			polygons.append(polygon)
	navigation_mesh.vertices = vertices
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = navigation_mesh
	maze_root.add_child(navigation_region)

func _spawn_health_orbs() -> void:
	var available_cells: Array[Vector2i] = []
	var exit_cell := _exit_cell()
	for z in range(1, maze_size - 1):
		for x in range(1, maze_size - 1):
			var cell := Vector2i(x, z)
			if not maze[z][x] and cell != Vector2i(1, 1) and cell != exit_cell:
				available_cells.append(cell)
	available_cells.shuffle()
	for index in range(mini(HEALTH_ORB_COUNT, available_cells.size())):
		var orb := Area3D.new()
		orb.name = "HealthOrb_%d" % index
		orb.set_script(HEALTH_ORB_SCRIPT)
		orb.set("heal_amount", HEALTH_ORB_AMOUNT)
		orb.position = _cell_position(available_cells[index].x, available_cells[index].y) + Vector3(0.0, 0.65, 0.0)
		orb.collision_layer = 0
		orb.collision_mask = 1
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.55
		collision.shape = shape
		orb.add_child(collision)
		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 1.0, 0.5)
		material.emission_enabled = true
		material.emission = Color(0.05, 0.9, 0.25)
		material.emission_energy_multiplier = 4.0
		visual.material_override = material
		orb.add_child(visual)
		var light := OmniLight3D.new()
		light.light_color = Color(0.15, 1.0, 0.4)
		light.light_energy = 1.4
		light.omni_range = 2.8
		orb.add_child(light)
		maze_root.add_child(orb)

func _add_lights() -> void:
	roof_lights.clear()
	for z in range(1, maze_size, 4):
		for x in range(1, maze_size, 4):
			if not maze[z][x]:
				var light := OmniLight3D.new()
				light.light_color = Color(1.0, 0.78, 0.48)
				var broken := rng.randf() < 0.02
				light.light_energy = 0.0 if broken else 1.15
				light.omni_range = 5.2
				light.position = _cell_position(x, z) + Vector3(0.0, 2.55, 0.0)
				maze_root.add_child(light)
				roof_lights.append({
					"light": light,
					"base_energy": 1.15,
					"next_flicker": rng.randf_range(3.0, 10.0),
					"flicker_left": 0.0,
					"pulse_timer": 0.0,
					"broken": broken
				})
				var fixture := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.55, 0.04, 0.55)
				fixture.mesh = mesh
				fixture.position = light.position
				fixture.material_override = ceiling_material if broken else exit_material
				maze_root.add_child(fixture)

func _spawn_player() -> void:
	if is_instance_valid(player):
		player.queue_free()
	player = PLAYER_SCRIPT.new()
	if player == null:
		return
	player.name = "Player"
	add_child(player)
	player.position = _cell_position(1, 1) + Vector3(0.0, 0.03, 0.0)
	player.current_health = player.maximum_health
	player.set_battery_mode(selected_battery_mode)
	player.flashlight_enabled = false
	player._update_flashlight_visibility()
	player.health_changed.connect(_update_health_bar)
	player.battery_changed.connect(_update_battery_bar)
	player.damage_taken.connect(_show_damage_feedback)
	player.health_restored.connect(_show_heal_feedback)
	player.died.connect(_on_player_died)
	player.health_changed.emit(player.current_health, player.maximum_health)
	_spawn_howler()

func _show_damage_feedback() -> void:
	if is_instance_valid(feedback_overlay):
		feedback_overlay.show_damage()

func _show_heal_feedback() -> void:
	if is_instance_valid(feedback_overlay):
		feedback_overlay.show_heal()

func _update_health_bar(current_health: float, maximum_health: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_label.text = "HEALTH  %d%%" % roundi(current_health / maximum_health * 100.0)

func _update_battery_bar(current_battery: float, maximum_battery: float) -> void:
	if battery_bar == null:
		return
	battery_bar.max_value = maximum_battery
	battery_bar.value = current_battery
	battery_label.text = "BATTERY  %d%%" % roundi(current_battery / maximum_battery * 100.0)

func _on_player_died() -> void:
	if game_finished or game_over:
		return
	game_over = true
	status_label.text = "You were caught"
	death_overlay.visible = true
	death_message.visible = true
	_show_end_state("YOU DIED", "PRESS R OR USE THE BUTTON BELOW TO TRY AGAIN")
	if is_instance_valid(howler):
		howler.queue_free()
		howler = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _complete_maze() -> void:
	game_finished = true
	game_over = false
	player.input_enabled = false
	player.velocity = Vector3.ZERO
	if is_instance_valid(howler):
		howler.queue_free()
		howler = null
	level += 1
	maze_size = BASE_MAZE_SIZE + (level - 1) * 2
	new_game(false, true)

func _show_end_state(title: String, subtitle: String) -> void:
	end_message.text = "%s\n\n%s" % [title, subtitle]
	end_overlay.visible = true

func _start_game() -> void:
	if not is_instance_valid(player):
		return
	game_started = true
	player.set_battery_mode(selected_battery_mode)
	player.input_enabled = true
	player.flashlight_enabled = true
	player._update_flashlight_visibility()
	if is_instance_valid(howler):
		howler.set_process(true)
		howler.set_physics_process(true)
	if is_instance_valid(start_overlay):
		start_overlay.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _spawn_howler() -> void:
	var howler_scene: PackedScene = preload("res://Howler.tscn")
	howler = howler_scene.instantiate()
	howler.name = "Howler"
	howler.add_to_group("howler")
	howler.max_health = HOWLER_BASE_HEALTH * pow(1.1, level - 1)
	add_child(howler)
	howler.position = _choose_howler_spawn_position()
	howler.look_at(player.global_position, Vector3.UP)
	if howler.has_method("set_player_reference"):
		howler.set_player_reference(player)
	howler.current_health = howler.max_health
	howler.is_dead = false
	howler.respawn_timer = 0.0
	howler.health_changed.connect(_update_howler_health_bar)

func _update_howler_health_bar(current_health: float, maximum_health: float) -> void:
	if not is_instance_valid(howler_health_bar):
		return
	howler_health_bar.max_value = maximum_health
	howler_health_bar.value = current_health
	if is_instance_valid(howler_health_label):
		howler_health_label.text = "HOWLER  %d%%" % roundi((current_health / maximum_health) * 100.0)

func _player_can_see_howler(target: Node3D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(target):
		return false
	var camera_node = player.get("camera")
	if camera_node == null:
		return false
	var to_target: Vector3 = target.global_position - camera_node.global_position
	var distance: float = to_target.length()
	if distance > 25.0:
		return false
	var forward: Vector3 = -camera_node.global_transform.basis.z
	var dot: float = forward.dot(to_target.normalized())
	if dot < 0.15:
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera_node.global_position, target.global_position)
	query.exclude = [player, target]
	var hit := world.direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _choose_howler_spawn_position() -> Vector3:
	var minimum_distance := CELL_SIZE * 3.0
	var candidates: Array[Vector3] = []
	for z in range(1, maze_size - 1):
		for x in range(1, maze_size - 1):
			if maze[z][x]:
				continue
			var candidate := _cell_position(x, z)
			if candidate.distance_to(player.global_position) >= minimum_distance:
				candidates.append(candidate)
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)] + Vector3(0.0, 0.05, 0.0)
	return player.position + Vector3(0.0, 0.05, -1.4)

func _cell_position(x: int, z: int) -> Vector3:
	return Vector3((x - maze_size / 2.0 + 0.5) * CELL_SIZE, 0.0, (z - maze_size / 2.0 + 0.5) * CELL_SIZE)

func _exit_cell() -> Vector2i:
	return Vector2i(maze_size - 2, maze_size - 2)

func _add_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)

func _create_materials() -> void:
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.68, 0.58, 0.32)
	wall_material.roughness = 0.92
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.31, 0.27, 0.18)
	floor_material.roughness = 1.0
	ceiling_material = StandardMaterial3D.new()
	ceiling_material.albedo_color = Color(0.52, 0.45, 0.28)
	ceiling_material.roughness = 1.0
	exit_material = StandardMaterial3D.new()
	exit_material.albedo_color = Color(1.0, 0.32, 0.06)
	exit_material.emission_enabled = true
	exit_material.emission = Color(1.0, 0.12, 0.02)
	exit_material.emission_energy_multiplier = 5.0

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.035, 0.025, 0.82)
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(250.0, 124.0)
	layer.add_child(panel)
	seed_label = Label.new()
	seed_label.position = Vector2(16.0, 10.0)
	seed_label.add_theme_color_override("font_color", Color(0.88, 0.67, 0.36))
	seed_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(seed_label)
	status_label = Label.new()
	status_label.position = Vector2(16.0, 35.0)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.73))
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)
	health_label = Label.new()
	health_label.position = Vector2(16.0, 55.0)
	health_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.24))
	health_label.add_theme_font_size_override("font_size", 10)
	health_label.text = "HEALTH  100%"
	panel.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(16.0, 67.0)
	health_bar.size = Vector2(218.0, 10.0)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color(0.12, 0.08, 0.06, 0.95)
	health_background.border_width_left = 1
	health_background.border_width_top = 1
	health_background.border_width_right = 1
	health_background.border_width_bottom = 1
	health_background.border_color = Color(0.45, 0.22, 0.14, 0.9)
	health_bar.add_theme_stylebox_override("background", health_background)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.85, 0.22, 0.1, 1.0)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	panel.add_child(health_bar)
	battery_label = Label.new()
	battery_label.position = Vector2(16.0, 85.0)
	battery_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.95))
	battery_label.add_theme_font_size_override("font_size", 10)
	battery_label.text = "BATTERY  100%"
	panel.add_child(battery_label)
	battery_bar = ProgressBar.new()
	battery_bar.name = "BatteryBar"
	battery_bar.position = Vector2(16.0, 97.0)
	battery_bar.size = Vector2(218.0, 10.0)
	battery_bar.show_percentage = false
	battery_bar.min_value = 0.0
	battery_bar.max_value = 100.0
	battery_bar.value = 100.0
	var battery_background := StyleBoxFlat.new()
	battery_background.bg_color = Color(0.08, 0.1, 0.12, 0.95)
	battery_background.border_width_left = 1
	battery_background.border_width_top = 1
	battery_background.border_width_right = 1
	battery_background.border_width_bottom = 1
	battery_background.border_color = Color(0.35, 0.45, 0.58, 0.9)
	battery_bar.add_theme_stylebox_override("background", battery_background)
	var battery_fill := StyleBoxFlat.new()
	battery_fill.bg_color = Color(0.52, 0.71, 1.0, 1.0)
	battery_bar.add_theme_stylebox_override("fill", battery_fill)
	panel.add_child(battery_bar)
	howler_health_label = Label.new()
	howler_health_label.position = Vector2(1020.0, 24.0)
	howler_health_label.add_theme_color_override("font_color", Color(0.78, 0.52, 1.0))
	howler_health_label.add_theme_font_size_override("font_size", 10)
	howler_health_label.visible = false
	layer.add_child(howler_health_label)
	howler_health_bar = ProgressBar.new()
	howler_health_bar.name = "HowlerHealthBar"
	howler_health_bar.position = Vector2(1016.0, 38.0)
	howler_health_bar.size = Vector2(220.0, 12.0)
	howler_health_bar.show_percentage = false
	howler_health_bar.min_value = 0.0
	howler_health_bar.max_value = 100.0
	howler_health_bar.value = 100.0
	howler_health_bar.visible = false
	var howler_background := StyleBoxFlat.new()
	howler_background.bg_color = Color(0.1, 0.06, 0.14, 0.9)
	howler_background.border_width_left = 1
	howler_background.border_width_top = 1
	howler_background.border_width_right = 1
	howler_background.border_width_bottom = 1
	howler_background.border_color = Color(0.42, 0.25, 0.6, 0.9)
	howler_health_bar.add_theme_stylebox_override("background", howler_background)
	var howler_fill := StyleBoxFlat.new()
	howler_fill.bg_color = Color(0.58, 0.38, 0.95, 1.0)
	howler_health_bar.add_theme_stylebox_override("fill", howler_fill)
	layer.add_child(howler_health_bar)
	var help := Label.new()
	help.text = "WASD  MOVE     MOUSE  LOOK     R  NEW GAME     Q  QUIT"
	help.position = Vector2(24.0, 670.0)
	help.add_theme_color_override("font_color", Color(0.62, 0.56, 0.42, 0.9))
	help.add_theme_font_size_override("font_size", 12)
	layer.add_child(help)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(637.0, 348.0)
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 0.75))
	crosshair.add_theme_font_size_override("font_size", 18)
	layer.add_child(crosshair)
	feedback_overlay = FEEDBACK_OVERLAY_SCRIPT.new()
	feedback_overlay.name = "FeedbackOverlay"
	layer.add_child(feedback_overlay)
	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.color = Color(0.36, 0.0, 0.0, 0.78)
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.visible = false
	layer.add_child(death_overlay)
	death_message = Label.new()
	death_message.name = "DeathMessage"
	death_message.text = "YOU DIED\n\nPRESS R TO RESTART"
	death_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_message.position = Vector2(-220.0, -90.0)
	death_message.size = Vector2(440.0, 180.0)
	death_message.add_theme_color_override("font_color", Color(1.0, 0.86, 0.78))
	death_message.add_theme_font_size_override("font_size", 26)
	death_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_message.visible = false
	layer.add_child(death_message)
	end_overlay = ColorRect.new()
	end_overlay.name = "EndOverlay"
	end_overlay.color = Color(0.015, 0.01, 0.008, 0.72)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.visible = false
	layer.add_child(end_overlay)
	end_message = Label.new()
	end_message.name = "EndMessage"
	end_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end_message.position = Vector2(-360.0, -150.0)
	end_message.size = Vector2(720.0, 180.0)
	end_message.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	end_message.add_theme_font_size_override("font_size", 28)
	end_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(end_message)
	new_game_button = Button.new()
	new_game_button.name = "NewGameButton"
	new_game_button.text = "NEW GAME"
	new_game_button.anchor_left = 0.5
	new_game_button.anchor_top = 0.5
	new_game_button.anchor_right = 0.5
	new_game_button.anchor_bottom = 0.5
	new_game_button.size = Vector2(220.0, 48.0)
	new_game_button.offset_left = -110.0
	new_game_button.offset_top = 58.0
	new_game_button.offset_right = 110.0
	new_game_button.offset_bottom = 106.0
	new_game_button.add_theme_font_size_override("font_size", 18)
	new_game_button.pressed.connect(new_game)
	end_overlay.add_child(new_game_button)
	start_overlay = ColorRect.new()
	start_overlay.name = "StartOverlay"
	start_overlay.color = Color(0.015, 0.01, 0.008, 0.86)
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	start_overlay.visible = false
	layer.add_child(start_overlay)
	start_message = Label.new()
	start_message.name = "StartMessage"
	start_message.text = "YOU'VE LANDED IN A STRANGE BACKROOMS\n\nCHOOSE FLASHLIGHT POWER MODE"
	start_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	start_message.position = Vector2(-380.0, -185.0)
	start_message.size = Vector2(760.0, 130.0)
	start_message.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	start_message.add_theme_font_size_override("font_size", 28)
	start_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.add_child(start_message)
	for index in range(3):
		var button := Button.new()
		button.text = [
			"NEVER DRAINS",
			"DRAINS, RECHARGES OFF",
			"DRAINS, NO RECHARGE",
		][index]
		button.anchor_left = 0.5
		button.anchor_top = 0.5
		button.anchor_right = 0.5
		button.anchor_bottom = 0.5
		button.size = Vector2(300.0, 42.0)
		button.offset_left = -150.0
		button.offset_top = -35.0 + index * 54.0
		button.offset_right = 150.0
		button.offset_bottom = 7.0 + index * 54.0
		button.pressed.connect(func() -> void:
			_selected_start_mode(index)
		)
		button.add_theme_font_size_override("font_size", 16)
		start_overlay.add_child(button)
		battery_mode_buttons.append(button)
	_selected_start_mode(selected_battery_mode)
	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "START"
	start_button.anchor_left = 0.5
	start_button.anchor_top = 0.5
	start_button.anchor_right = 0.5
	start_button.anchor_bottom = 0.5
	start_button.size = Vector2(220.0, 50.0)
	start_button.offset_left = -110.0
	start_button.offset_top = 154.0
	start_button.offset_right = 110.0
	start_button.offset_bottom = 204.0
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.pressed.connect(_start_game)
	start_overlay.add_child(start_button)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Leave the Maze?"
	quit_dialog.dialog_text = "Are you sure you want to quit?"
	quit_dialog.ok_button_text = "Quit"
	quit_dialog.cancel_button_text = "Stay"
	quit_dialog.confirmed.connect(_quit_game)
	layer.add_child(quit_dialog)
	new_game_dialog = ConfirmationDialog.new()
	new_game_dialog.title = "Start a New Game?"
	new_game_dialog.dialog_text = "Your progress will be reset to level 1. Are you sure?"
	new_game_dialog.ok_button_text = "Restart"
	new_game_dialog.cancel_button_text = "Stay"
	new_game_dialog.confirmed.connect(new_game)
	layer.add_child(new_game_dialog)

func _selected_start_mode(mode: int) -> void:
	selected_battery_mode = clampi(mode, MazePlayer.BatteryMode.NEVER_DRAIN, MazePlayer.BatteryMode.DRAIN_NO_RECHARGE)
	if is_instance_valid(player):
		player.set_battery_mode(selected_battery_mode)
	for index in range(battery_mode_buttons.size()):
		var button: Button = battery_mode_buttons[index]
		button.modulate = Color(1.0, 1.0, 1.0, 1.0 if index == selected_battery_mode else 0.6)

func _quit_game() -> void:
	get_tree().quit()
