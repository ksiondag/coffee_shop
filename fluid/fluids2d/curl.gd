extends RefCounted


const SHADER_PATH := "res://fluid/shaders/curl.glsl"
const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FBO = preload("res://gpu/fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

@export var radius: float

var _curl: FBO
var _velocity: DoubleFBO
var _compute_shader: ComputeShader


class CurlShader extends ComputeShader:
	var _node
	func _init(node, gpu_resource, shader_path) -> void:
		super(gpu_resource, shader_path)
		_node = node
	
	func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void:
		return _node.set_uniform_sets(rd, shader, compute_list)


var velocity_uniform_set: RID
var curl_uniform_set: RID
func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int):
	# Velocity set
	if velocity_uniform_set != null and velocity_uniform_set.is_valid():
		rd.free_rid(velocity_uniform_set)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(_velocity.get_texture_rd())
	velocity_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, velocity_uniform_set, 0)

	# Curl set
	if curl_uniform_set == null or not curl_uniform_set.is_valid():
		uniform = RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(_curl.get_texture_rd())
		curl_uniform_set = rd.uniform_set_create([uniform], shader, 1)
	rd.compute_list_bind_uniform_set(compute_list, curl_uniform_set, 1)


func _init(fluid_fields: FluidFields) -> void:
	_curl = fluid_fields.curl
	_velocity = fluid_fields.velocity
	_compute_shader = CurlShader.new(self, _curl, SHADER_PATH)


func process(_delta: float) -> void:
	_compute_shader.process([])


# RenderingThread functions
