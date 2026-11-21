extends Node

const SHADER_PATH := "res://fluid/shaders/clear.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var color: Color

var double_fbo: DoubleFBO
var compute_shader: ComputeShader
var texture_size: Vector2i


class ClearShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
	if uniform_set != null and uniform_set.is_valid():
		rd.free_rid(uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(double_fbo.get_texture_rd())
	uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)


func _clear() -> void:
	if compute_shader != null:
		var push_constants = PackedFloat32Array([
			# color to clear to
			color.r,
			color.g,
			color.b,
			color.a,
		]).to_byte_array()
		compute_shader.process(push_constants)


func _input(event) -> void:
	if event.is_action_pressed("right_click"):
		_clear()


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if compute_shader != null:
		compute_shader.release()
	compute_shader = null


func _process(delta: float) -> void:
	# Only send splat on click
	pass


func _on_view_resized(_size: Vector2) -> void:
	double_fbo = fluid_fields.dye
	compute_shader = ClearShader.new(self, double_fbo, SHADER_PATH)
	_clear()
