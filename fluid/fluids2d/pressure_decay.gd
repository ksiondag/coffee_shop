class_name PressureDecay
extends RefCounted


const SHADER_PATH := "res://fluid/shaders/pressure_decay.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")

var _pressure: DoubleFBO
var _compute_shader: ComputeShader


class PressureDecayShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var pressure_read_uniform_set: RID
var pressure_write_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# Both pressure sets are rebuilt each dispatch so they follow DoubleFBO swaps
	if pressure_read_uniform_set.is_valid():
		rd.free_rid(pressure_read_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_pressure.get_texture_rd())
	pressure_read_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, pressure_read_uniform_set, 0)

	if pressure_write_uniform_set.is_valid():
		rd.free_rid(pressure_write_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_pressure.get_write_texture_rd())
	pressure_write_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, pressure_write_uniform_set, 1)


func _init(pressure: DoubleFBO) -> void:
	_pressure = pressure
	_compute_shader = PressureDecayShader.new(self, _pressure, SHADER_PATH)


func process(_delta: float, decay: float) -> void:
	var push_constants := PackedFloat32Array([decay]).to_byte_array()
	_compute_shader.process(push_constants)
	_pressure.swap()


# Frees the GPU resources and breaks the reference cycle between this pass and
# its shader (_node), so both can be freed.
func release() -> void:
	_compute_shader.release()
	_compute_shader._node = null
