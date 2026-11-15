extends Node

const SHADER_PATH := "res://fluid/splat.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")

@export var output: Texture2DRD

// NOTE/TODO: The texture size should match the height/width ratio of the view
@export var texture_size: Vector2i = Vector2i(512, 512)

@export_range(0.0, 1.0) var red: float
@export_range(0.0, 1.0) var green: float
@export_range(0.0, 1.0) var blue: float

@export_range(0.0, 1.0) var radius: float

# TODO: We need to set variables in the compute shader, which the compute
# shader class will handle for us
var compute_shader: ComputeShader

func _input(event) -> void:
	if event.is_action_pressed("click"):
		# Must match the shader's Params block field for field: cursor, blue, padding (16 bytes)
		print(event)
		var position: Vector2 = event.position
		

		var bytes := PackedFloat32Array([
			# color
			red,
			green,
			blue,
			1.0,
			# cursor
			event.position.x / 1151.0,
			event.position.y / 645.0,
			# radius
			radius,
			# padding
			0.0
		]).to_byte_array()
		if compute_shader != null:
			compute_shader.process(bytes)


func _enter_tree() -> void:
	compute_shader = ComputeShader.new(output, texture_size, SHADER_PATH)


func _exit_tree() -> void:
	if compute_shader != null:
		compute_shader.free()
	compute_shader = null


func _process(delta: float) -> void:
	# Only send splat on click
	pass
