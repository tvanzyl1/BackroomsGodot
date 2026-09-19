extends Node3D

const PLAYER_SCRIPT: Script = preload("res://player.gd")
const HEALTH_ORB_SCRIPT: Script = preload("res://HealthOrb.gd")
const FEEDBACK_OVERLAY_SCRIPT: Script = preload("res://FeedbackOverlay.gd")
const MAZE_SIZE: int = 17
const CELL_SIZE: float = 3.2
const EXIT_CELL := Vector2i(MAZE_SIZE - 2, MAZE_SIZE - 2)
const WALL_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.18
const HEALTH_ORB_COUNT: int = 3
const HEALTH_ORB_AMOUNT: float = 25.0

var maze: Array[Array] = []
var maze_root: Node3D
var howler: Node3D
var player: MazePlayer
var rng := RandomNumberGenerator.new()
var generation: int = 0
var status_label: Label
var seed_label: Label
var health_label: Label
var health_bar: ProgressBar
var feedback_overlay: Control
var death_overlay: ColorRect
var death_message: Label
var end_overlay: ColorRect
var end_message: Label
var new_game_button: Button
var quit_dialog: ConfirmationDialog
var roof_lights: Array[Dictionary] = []
var noise_manager: Node
var game_finished: bool = false
var game_over: bool = false
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
		new_game()
	if event.is_action_pressed("quit_game") and not quit_dialog.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit_dialog.popup_centered()
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func new_game() -> void:
	generation += 1
	game_finished = false
	game_over = false
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
	death_overlay.visible = false
	death_message.visible = false
	end_overlay.visible = false
	seed_label.text = "SECTOR %02d  //  SEED %08d" % [generation, rng.seed]
	status_label.text = "Find the way out"

func _process(delta: float) -> void:
	if not game_finished and is_instance_valid(player) and player.global_position.distance_to(exit_position) < CELL_SIZE * 0.42:
		_complete_maze()
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
	for z in range(MAZE_SIZE):
		var row: Array = []
		for x in range(MAZE_SIZE):
			row.append(true)
		maze.append(row)
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	maze[1][1] = false
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for direction in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var next: Vector2i = current + direction
			if next.x > 0 and next.x < MAZE_SIZE - 1 and next.y > 0 and next.y < MAZE_SIZE - 1 and maze[next.y][next.x]:
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
		var x := rng.randi_range(1, MAZE_SIZE - 2)
		var z := rng.randi_range(1, MAZE_SIZE - 2)
		if (x + z) % 2 == 1:
			maze[z][x] = false

func _build_maze() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	maze_root.add_child(floor_body)
	_add_box(floor_body, Vector3(MAZE_SIZE * CELL_SIZE, 0.0, MAZE_SIZE * CELL_SIZE), Vector3(0.0, -0.12, 0.0), floor_material)
	_add_navigation_region()
	var ceiling_body := StaticBody3D.new()
	ceiling_body.name = "Ceiling"
	maze_root.add_child(ceiling_body)
	_add_box(ceiling_body, Vector3(MAZE_SIZE * CELL_SIZE, 0.18, MAZE_SIZE * CELL_SIZE), Vector3(0.0, WALL_HEIGHT, 0.0), ceiling_material)
	for z in range(MAZE_SIZE):
		for x in range(MAZE_SIZE):
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
	exit_position = _cell_position(EXIT_CELL.x, EXIT_CELL.y)
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
	for z in range(MAZE_SIZE):
		for x in range(MAZE_SIZE):
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
	var exit_cell := Vector2i(MAZE_SIZE - 2, MAZE_SIZE - 2)
	for z in range(1, MAZE_SIZE - 1):
		for x in range(1, MAZE_SIZE - 1):
			var cell := Vector2i(x, z)
			if not maze[z][x] and cell != Vector2i(1, 1) and cell != exit_cell:
				available_cells.append(cell)
	available_cells.shuffle()
	for index in range(mini(HEALTH_ORB_COUNT, available_cells.size())):
		var orb := Area3D.new()
		orb.name = "HealthOrb_%d" % index
		orb.set_script(HEALTH_ORB_SCRIPT)
		orb.heal_amount = HEALTH_ORB_AMOUNT
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
	for z in range(1, MAZE_SIZE, 4):
		for x in range(1, MAZE_SIZE, 4):
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
	if player:
		player.queue_free()
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	add_child(player)
	player.position = _cell_position(1, 1) + Vector3(0.0, 0.03, 0.0)
	player.health_changed.connect(_update_health_bar)
	player.damage_taken.connect(_show_damage_feedback)
	player.health_restored.connect(_show_heal_feedback)
	player.died.connect(_on_player_died)
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
	status_label.text = "You escaped the backrooms"
	_show_end_state("YOU ESCAPED THE BACKROOMS", "THE MAZE HAS RELEASED YOU")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _show_end_state(title: String, subtitle: String) -> void:
	end_message.text = "%s\n\n%s" % [title, subtitle]
	end_overlay.visible = true

func _spawn_howler() -> void:
	var howler_scene: PackedScene = preload("res://Howler.tscn")
	howler = howler_scene.instantiate()
	howler.name = "Howler"
	add_child(howler)
	howler.position = _choose_howler_spawn_position()
	howler.look_at(player.global_position, Vector3.UP)
	if howler.has_method("set_player_reference"):
		howler.set_player_reference(player)

func _choose_howler_spawn_position() -> Vector3:
	var minimum_distance := CELL_SIZE * 3.0
	var candidates: Array[Vector3] = []
	for z in range(1, MAZE_SIZE - 1):
		for x in range(1, MAZE_SIZE - 1):
			if maze[z][x]:
				continue
			var candidate := _cell_position(x, z)
			if candidate.distance_to(player.global_position) >= minimum_distance:
				candidates.append(candidate)
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)] + Vector3(0.0, 0.05, 0.0)
	return player.position + Vector3(0.0, 0.05, -1.4)

func _cell_position(x: int, z: int) -> Vector3:
	return Vector3((x - MAZE_SIZE / 2.0 + 0.5) * CELL_SIZE, 0.0, (z - MAZE_SIZE / 2.0 + 0.5) * CELL_SIZE)

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
	panel.size = Vector2(250.0, 84.0)
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
	var help := Label.new()
	help.text = "WASD  MOVE     MOUSE  LOOK     R  NEW MAZE     Q  QUIT"
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
	new_game_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	new_game_button.position = Vector2(-110.0, 58.0)
	new_game_button.size = Vector2(220.0, 48.0)
	new_game_button.add_theme_font_size_override("font_size", 18)
	new_game_button.pressed.connect(new_game)
	end_overlay.add_child(new_game_button)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Leave the Maze?"
	quit_dialog.dialog_text = "Are you sure you want to quit?"
	quit_dialog.ok_button_text = "Quit"
	quit_dialog.cancel_button_text = "Stay"
	quit_dialog.confirmed.connect(_quit_game)
	layer.add_child(quit_dialog)

func _quit_game() -> void:
	get_tree().quit()
