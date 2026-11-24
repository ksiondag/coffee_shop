class_name Pressure
extends RefCounted


const SHADER_PATH := "res://fluid/shaders/pressure.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FBO = preload("res://gpu/fbo.gd")

var _divergence: FBO
var _pressure: DoubleFBO
var _compute_shader: ComputeShader


class PressureShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var divergence_uniform_set: RID
var pressure_read_uniform_set: RID
var pressure_write_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# Divergence set
	var uniform: RDUniform
	if not divergence_uniform_set.is_valid():
		uniform = RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(_divergence.get_texture_rd())
		divergence_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, divergence_uniform_set, 0)

	# Pressure sets are rebuilt each dispatch so they follow DoubleFBO swaps
	if pressure_read_uniform_set.is_valid():
		rd.free_rid(pressure_read_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_pressure.get_texture_rd())
	pressure_read_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, pressure_read_uniform_set, 1)

	if pressure_write_uniform_set.is_valid():
		rd.free_rid(pressure_write_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_pressure.get_write_texture_rd())
	pressure_write_uniform_set = rd.uniform_set_create([uniform], shader, 2)
	rd.compute_list_bind_uniform_set(compute_list, pressure_write_uniform_set, 2)


func _init(divergence: FBO, pressure: DoubleFBO) -> void:
	_divergence = divergence
	_pressure = pressure
	_compute_shader = PressureShader.new(self, _pressure, SHADER_PATH)


func process(_delta: float, iterations: int) -> void:
	for i in range(iterations):
		_compute_shader.process([])
		_pressure.swap()


# Frees the GPU resources and breaks the reference cycle between this pass and
# its shader (_node), so both can be freed.
func release() -> void:
	_compute_shader.release()
	_compute_shader._node = null
