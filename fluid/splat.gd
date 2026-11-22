extends Node


const SHADER_PATH := "res://fluid/shaders/splat.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var dye: DoubleFBO
var dye_shader: ComputeShader

var velocity: DoubleFBO
var velocity_shader: ComputeShader

var texture_size: Vector2i

class DyeSplatShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_dye_uniform_sets(rd, shader, compute_list)


var dye_uniform_set: RID
func set_dye_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	if dye_uniform_set != null and dye_uniform_set.is_valid():
		rd.free_rid(dye_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(dye.get_texture_rd())
	dye_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, dye_uniform_set, 0)


class VelocitySplatShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node

	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_velocity_uniform_sets(rd, shader, compute_list)


var velocity_uniform_set: RID
func set_velocity_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	if velocity_uniform_set != null and velocity_uniform_set.is_valid():
		rd.free_rid(velocity_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(velocity.get_texture_rd())
	velocity_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, velocity_uniform_set, 0)


func _input(event) -> void:
	if event.is_action_pressed("click"):
		if dye_shader != null:
			var dye_push_constants = PackedFloat32Array([
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
			dye_shader.process(dye_push_constants)
		if velocity_shader != null:
			# TODO: Temporary velocity setting to see it working
			# We'll be building out how we splat velocity with our pitcher abstraction soon
			var velocity_push_constants = PackedFloat32Array([
				# x, y velocity
				-600.0,
				600.0,
				0.0,
				0.0,
				# cursor
				event.position.x,
				event.position.y,
				# radius
				radius,
				# padding
				0.0
			]).to_byte_array()
			velocity_shader.process(velocity_push_constants)


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if dye_shader != null:
		dye_shader.release()
	dye_shader = null
	if velocity_shader != null:
		velocity_shader.release()
	velocity_shader = null


func _process(delta: float) -> void:
	# Only send splat on click
	pass


func _on_view_resized(_size: Vector2) -> void:
	if dye == null && fluid_fields.initialized:
		dye = fluid_fields.dye
		dye.set_texture(output)
		dye_shader = DyeSplatShader.new(self, dye, SHADER_PATH)
	if velocity == null && fluid_fields.initialized:
		velocity = fluid_fields.velocity
		velocity_shader = VelocitySplatShader.new(self, velocity, SHADER_PATH)
