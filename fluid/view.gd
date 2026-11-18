extends TextureRect

const FluidFields = preload("res://fluid/fluid_fields.gd")

signal cursor_moved(uv: Vector2)
signal view_resized(size: Vector2)

@export var fluid_fields: FluidFields


func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		var pixel: Vector2 = event.position
		var cursor: Vector2 = pixel / self.get_viewport_rect().size
		cursor_moved.emit(cursor)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_resized() -> void:
	view_resized.emit(self.size)
	fluid_fields.initialize(self.size)
