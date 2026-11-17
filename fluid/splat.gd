extends Node

const SHADER_PATH := "res://fluid/shaders/splat.glsl"
const ComputeShaderNew = preload("res://gpu/compute_shader_new.gd")
const FBO = preload("res://gpu/fbo.gd")

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var fbo: FBO
var compute_shader: ComputeShaderNew
var texture_size: Vector2i

func _input(event) -> void:
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


func _on_view_resized(size: Vector2) -> void:
	if texture_size.y < 1.0 or texture_size.x < 1.0:
		texture_size = Vector2i(size.x, size.y)
		fbo = FBO.new(output, texture_size)
		compute_shader = ComputeShaderNew.new(fbo, SHADER_PATH)
