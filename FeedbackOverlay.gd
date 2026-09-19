extends Control

var damage_time: float = 0.0
var heal_time: float = 0.0
var heal_particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()

func show_damage() -> void:
	damage_time = 0.32
	queue_redraw()

func show_heal() -> void:
	heal_time = 0.7
	heal_particles.clear()
	for index in range(18):
		heal_particles.append({
			"position": Vector2.ZERO,
			"velocity": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(45.0, 105.0),
			"size": rng.randf_range(2.0, 5.0)
		})
	queue_redraw()

func _process(delta: float) -> void:
	damage_time = maxf(damage_time - delta, 0.0)
	heal_time = maxf(heal_time - delta, 0.0)
	for particle in heal_particles:
		particle.position += particle.velocity * delta
		particle.velocity *= 0.92
	if damage_time > 0.0 or heal_time > 0.0:
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if damage_time > 0.0:
		var damage_alpha := damage_time / 0.32
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.02, 0.01, damage_alpha * 0.12))
		draw_line(center + Vector2(-95.0, -115.0), center + Vector2(50.0, 25.0), Color(1.0, 0.12, 0.05, damage_alpha * 0.9), 7.0, true)
		draw_line(center + Vector2(-72.0, -54.0), center + Vector2(112.0, 128.0), Color(0.9, 0.04, 0.02, damage_alpha * 0.65), 3.0, true)
	if heal_time > 0.0:
		var heal_alpha := heal_time / 0.7
		for particle in heal_particles:
			var particle_position: Vector2 = center + particle.position
			draw_circle(particle_position, particle.size, Color(0.2, 1.0, 0.45, heal_alpha))