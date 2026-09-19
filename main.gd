extends Node3D

const PLAYER_SCRIPT: Script = preload("res://player.gd")

const MAZE_SIZE: int = 17
const CELL_SIZE: float = 3.2
const WALL_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.18

var maze: Array[Array] = []
var maze_root: Node3D
var howler: Node3D
var player: MazePlayer
var rng := RandomNumberGenerator.new()
var generation: int = 0
var status_label: Label
var seed_label: Label
var quit_dialog: ConfirmationDialog
var roof_lights: Array[Dictionary] = []

var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var ceiling_material: StandardMaterial3D
var exit_material: StandardMaterial3D

func _ready() -> void:
	rng.randomize()
	_create_materials()
	_create_hud()
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
	seed_label.text = "SECTOR %02d  //  SEED %08d" % [generation, rng.seed]
	status_label.text = "Find the way out"

func _process(delta: float) -> void:
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
	var exit_cell := Vector2i(MAZE_SIZE - 2, MAZE_SIZE - 2)
	var exit_marker := MeshInstance3D.new()
	exit_marker.name = "ExitLight"
	var exit_mesh := CylinderMesh.new()
	exit_mesh.top_radius = 0.18
	exit_mesh.bottom_radius = 0.18
	exit_mesh.height = 0.12
	exit_marker.mesh = exit_mesh
	exit_marker.position = _cell_position(exit_cell.x, exit_cell.y) + Vector3(0.0, 0.3, 0.0)
	exit_marker.material_override = exit_material
	maze_root.add_child(exit_marker)
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Color(0.95, 0.35, 0.08)
	exit_light.light_energy = 2.2
	exit_light.omni_range = 4.5
	exit_light.position = exit_marker.position + Vector3(0.0, 1.0, 0.0)
	maze_root.add_child(exit_light)
	_add_lights()

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
	_spawn_howler()

func _spawn_howler() -> void:
	var howler_scene: PackedScene = preload("res://Howler.tscn")
	howler = howler_scene.instantiate()
	howler.name = "Howler"
	add_child(howler)
	var spawn_offset := Vector3(0.0, 0.05, -1.4)
	howler.position = player.position + spawn_offset
	howler.rotation = player.rotation
	if howler.has_method("set_player_reference"):
		howler.set_player_reference(player)

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
	panel.size = Vector2(250.0, 74.0)
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
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Leave the Maze?"
	quit_dialog.dialog_text = "Are you sure you want to quit?"
	quit_dialog.ok_button_text = "Quit"
	quit_dialog.cancel_button_text = "Stay"
	quit_dialog.confirmed.connect(_quit_game)
	layer.add_child(quit_dialog)

func _quit_game() -> void:
	get_tree().quit()
