class_name Advection
extends RefCounted


const SHADER_PATH := "res://fluid/shaders/advection.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

# TODO: These are config values (Pavel's VELOCITY_DISSIPATION / DENSITY_DISSIPATION),
# when porting over config numbers
const VELOCITY_DISSIPATION := 0.2
const DYE_DISSIPATION := 1.0

var dissipation: float

var _velocity: DoubleFBO
var _source: DoubleFBO
var _compute_shader: ComputeShader


class AdvectionShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var velocity_uniform_set: RID
var source_read_uniform_set: RID
var source_write_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# All sets are rebuilt each dispatch so they follow DoubleFBO swaps.
	# When velocity advects itself, sets 0 and 1 hold the same read-only texture.
	if velocity_uniform_set.is_valid():
		rd.free_rid(velocity_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_velocity.get_texture_rd())
	velocity_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, velocity_uniform_set, 0)

	if source_read_uniform_set.is_valid():
		rd.free_rid(source_read_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_source.get_texture_rd())
	source_read_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, source_read_uniform_set, 1)

	if source_write_uniform_set.is_valid():
		rd.free_rid(source_write_uniform_set)
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_source.get_write_texture_rd())
	source_write_uniform_set = rd.uniform_set_create([uniform], shader, 2)
	rd.compute_list_bind_uniform_set(compute_list, source_write_uniform_set, 2)


# source is the field being carried: fluid_fields.velocity or fluid_fields.dye.
# TODO: This reveals a weakness in the template I've been following
# Each of these fluids2d classes are given the whole of fluid fields, that's bad coupling
func _init(fluid_fields: FluidFields, source: DoubleFBO, source_dissipation: float) -> void:
	_velocity = fluid_fields.velocity
	_source = source
	dissipation = source_dissipation
	# The dispatch covers the source, which may differ in size from velocity.
	_compute_shader = AdvectionShader.new(self, _source, SHADER_PATH)


# Call on the render thread, like the other passes in Fluids2D._step().
func process(delta: float) -> void:
	var push_constants := PackedFloat32Array([
		delta,
		dissipation,
	]).to_byte_array()
	_compute_shader.process(push_constants)
	_source.swap()
