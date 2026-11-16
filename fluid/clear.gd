extends Node

const SHADER_PATH := "res://fluid/shaders/clear.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")

@export var output: Texture2DRD

@export var color: Color

var texture_size: Vector2i
var compute_shader: ComputeShader

func _clear() -> void:
	# Must match the shader's Params block field for field: cursor, blue, padding (16 bytes)
	var bytes := PackedFloat32Array([
		# color to clear to
		color.r,
		color.g,
		color.b,
		color.a,
	]).to_byte_array()
	if compute_shader != null:
		compute_shader.process(bytes)


func _input(event) -> void:
	if event.is_action_pressed("right_click"):
		_clear()


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if compute_shader != null:
		compute_shader.free()
	compute_shader = null


func _process(delta: float) -> void:
	# Only send splat on click
	pass


func _on_view_resized(size: Vector2) -> void:
	if texture_size.y < 1.0 or texture_size.x < 1.0:
		texture_size = Vector2i(size.x, size.y)
		compute_shader = ComputeShader.new(output, texture_size, SHADER_PATH)
		_clear()
