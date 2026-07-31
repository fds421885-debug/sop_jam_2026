extends HSlider




func _on_value_changed(value: float) -> void:
	var reversed_value = 100.0 - value
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(reversed_value / 100.0)
	)
