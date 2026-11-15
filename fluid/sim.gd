extends Node

const SHADER_PATH := "res://fluid/crosshair.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")

@export var output: Texture2DRD
@export var texture_size: Vector2i = Vector2i(512, 512)
@export_range(0.0, 1.0) var blue: float

var cursor := Vector2(0.5, 0.5)

func set_cursor(c: Vector2) -> void:
	cursor = c


# TODO: We need to set variables in the compute shader, which the compute
# shader class will handle for us
var compute_shader: ComputeShader

func _enter_tree() -> void:
	compute_shader = ComputeShader.new(output, texture_size, SHADER_PATH)


func _exit_tree() -> void:
	if compute_shader != null:
		compute_shader.free()
	compute_shader = null


func _process(delta: float) -> void:
	# Must match the shader's Params block field for field: cursor, blue, padding (16 bytes)
	var bytes := PackedFloat32Array([
		cursor.x,
		cursor.y,
		blue,
		0.0
	]).to_byte_array()
	#compute_shader.process(bytes)
