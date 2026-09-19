extends Area3D

@export var heal_amount: float = 25.0

var collected: bool = false
var visual: MeshInstance3D
var base_height: float
var animation_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_height = position.y

func _process(delta: float) -> void:
	animation_time += delta
	rotation.y += delta * 1.8
	position.y = base_height + sin(animation_time * 2.4) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player") or not body.has_method("restore_health"):
		return
	var current_health_value = body.get("current_health")
	var maximum_health_value = body.get("maximum_health")
	if current_health_value == null or maximum_health_value == null:
		return
	var current_health := float(current_health_value)
	var maximum_health := float(maximum_health_value)
	if maximum_health <= 0.0 or current_health >= maximum_health:
		return
	collected = true
	body.restore_health(heal_amount)
	queue_free()