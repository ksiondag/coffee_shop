class_name GaussianSplat
extends RefCounted


const SHADER_PATH := "res://fluid/shaders/gaussian_splat.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")

var _source: DoubleFBO
var _compute_shader: ComputeShader


class GaussianSplatShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var source_read_uniform_set: RID
var source_write_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# Both sets are rebuilt each dispatch so they follow DoubleFBO swaps
	if source_read_uniform_set.is_valid():
		rd.free_rid(source_read_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_source.get_texture_rd())
	source_read_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, source_read_uniform_set, 0)

	if source_write_uniform_set.is_valid():
		rd.free_rid(source_write_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_source.get_write_texture_rd())
	source_write_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, source_write_uniform_set, 1)


func _init(source: DoubleFBO) -> void:
	_source = source
	_compute_shader = GaussianSplatShader.new(self, _source, SHADER_PATH)


func process(point: Vector2, color: Color, radius: float, aspect_ratio: float = 1.0) -> void:
	var push_constants := PackedFloat32Array([
		color.r, color.g, color.b, color.a,
		point.x, point.y,
		radius,
		aspect_ratio,
	]).to_byte_array()
	_compute_shader.process(push_constants)
	_source.swap()


# Frees the GPU resources and breaks the reference cycle between this pass and
# its shader (_node), so both can be freed.
func release() -> void:
	_compute_shader.release()
	_compute_shader._node = null
