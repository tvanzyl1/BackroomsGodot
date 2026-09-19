@tool
extends BTAction

func _generate_name() -> String:
	return "Howler AI"

func _tick(delta: float) -> Status:
	var howler = agent
	if not is_instance_valid(howler) or not howler.has_method("_limbo_tick"):
		return FAILURE
	howler._limbo_tick(delta)
	return RUNNING