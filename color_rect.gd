extends ColorRect


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	var mouse_cursor: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Normalize between 0 and 1
	var normalized_mouse: Vector2 = mouse_cursor / viewport_size
	material.set_shader_parameter("mouse_cursor", normalized_mouse)
