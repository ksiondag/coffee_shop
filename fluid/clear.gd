extends Node

const SHADER_PATH := "res://fluid/shaders/clear.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD

@export var color: Color

var double_fbo: DoubleFBO
var compute_shader: ComputeShader
var texture_size: Vector2i

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


func _on_view_resized(_size: Vector2) -> void:
	if texture_size.y < 1.0 or texture_size.x < 1.0:
		double_fbo = fluid_fields.dye
		compute_shader = ComputeShader.new(double_fbo, SHADER_PATH)
		_clear()
