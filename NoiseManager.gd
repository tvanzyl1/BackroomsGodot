extends Node
class_name NoiseManager

signal noise_emitted(position: Vector3, loudness: float, source: StringName)

var _history: Array = []

func emit_noise(position: Vector3, loudness: float, source: StringName = "") -> void:
	_history.append({
		"position": position,
		"loudness": loudness,
		"source": source,
		"time": Time.get_ticks_msec()
	})
	if _history.size() > 64:
		_history.remove_at(0)
	noise_emitted.emit(position, loudness, source)

func get_recent_noise(position: Vector3, max_distance: float = 20.0, max_age_ms: int = 5000) -> Array:
	var now := Time.get_ticks_msec()
	var results: Array = []
	for entry in _history:
		var distance: float = entry["position"].distance_to(position)
		if distance > max_distance or now - int(entry["time"]) > max_age_ms:
			continue
		var perceived: Dictionary = entry.duplicate()
		perceived["perceived_loudness"] = float(entry["loudness"]) * clampf(1.0 - distance / max_distance, 0.0, 1.0)
		results.append(perceived)
	return results
