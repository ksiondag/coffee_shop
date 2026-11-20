extends Node


const SHADER_PATH := "res://fluid/shaders/splat.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const FBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var double_fbo: DoubleFBO
var compute_shader: ComputeShader
var texture_size: Vector2i

class SplatShader extends ComputeShader:
	pass


func _input(event) -> void:
	# TODO: temporary proof of swap functionality
	if event.is_action_pressed("space_bar"):
		double_fbo.swap()
	if event.is_action_pressed("click"):
		# Must match the shader's Params block field for field: cursor, blue, padding (16 bytes)
		var bytes := PackedFloat32Array([
			# color
			color.r,
			color.g,
			color.b,
			color.a,
			# cursor
			event.position.x,
			event.position.y,
			# radius
			radius,
			# padding
			0.0
		]).to_byte_array()
		if compute_shader != null:
			compute_shader.process(bytes)


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
	if double_fbo == null && fluid_fields.initialized:
		double_fbo = fluid_fields.dye
		double_fbo.set_texture(output)
		compute_shader = SplatShader.new(double_fbo, SHADER_PATH)
