class_name GradientSubtract
extends RefCounted


const SHADER_PATH := "res://fluid/shaders/gradient_subtract.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

var _pressure: DoubleFBO
var _velocity: DoubleFBO
var _compute_shader: ComputeShader


class GradientSubtractShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var pressure_uniform_set: RID
var velocity_read_uniform_set: RID
var velocity_write_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# All sets are rebuilt each dispatch so they follow DoubleFBO swaps
	if pressure_uniform_set.is_valid():
		rd.free_rid(pressure_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_pressure.get_texture_rd())
	pressure_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, pressure_uniform_set, 0)

	if velocity_read_uniform_set.is_valid():
		rd.free_rid(velocity_read_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_velocity.get_texture_rd())
	velocity_read_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, velocity_read_uniform_set, 1)

	if velocity_write_uniform_set.is_valid():
		rd.free_rid(velocity_write_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_velocity.get_write_texture_rd())
	velocity_write_uniform_set = rd.uniform_set_create([uniform], shader, 2)
	rd.compute_list_bind_uniform_set(compute_list, velocity_write_uniform_set, 2)


func _init(fluid_fields: FluidFields) -> void:
	_pressure = fluid_fields.pressure
	_velocity = fluid_fields.velocity
	_compute_shader = GradientSubtractShader.new(self, _velocity, SHADER_PATH)


func process(_delta: float) -> void:
	_compute_shader.process([])
	_velocity.swap()
