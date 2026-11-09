extends Node

const SHADER_PATH := "res://fluid/crosshair.glsl"

# Must match local_size_x / local_size_y in the shader
const GROUP_SIZE := 8

@export var output: Texture2DRD
@export var texture_size: Vector2i = Vector2i(512, 512)
@export_range(0.0, 1.0) var blue: float

var cursor := Vector2(0.5, 0.5)

func set_cursor(c: Vector2) -> void:
	cursor = c


func _enter_tree() -> void:
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_size))


func _exit_tree() -> void:
	if output:
		output.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_compute_resources)


func _process(_delta: float) -> void:
	if output and output.texture_rd_rid != texture_rd:
		output.texture_rd_rid = texture_rd

	RenderingServer.call_on_render_thread(_render_process.bind(cursor, blue))


# Rendering thread variables

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var texture_rd: RID
var uniform_set: RID
var size_rd: Vector2i


func _initialize_compute_code(size: Vector2i) -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("Sim: no RenderingDevice. Compute shaders need Forward+ or Mobile running on Vulkan/D3D12/Metal")
		return

	var shader_file: RDShaderFile = load(SHADER_PATH)
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("Sim: %s failed to compile:\n%s" % [SHADER_PATH, spirv.compile_error_compute])
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)

	var tf = RDTextureFormat.new()
	# DATA_FORMAT_R16G16B16A16_SFLOAT matches rgba16f in shader
	tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = size.x
	tf.height = size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	# SAMPLING: read by the TextureRect, STORAGE: written by imageStore
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	texture_rd = rd.texture_create(tf, RDTextureView.new(), [])
	size_rd = size

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	# binding = 0 in the shader
	uniform.binding = 0
	uniform.add_id(texture_rd)
	# set = 0 in the shader
	uniform_set = rd.uniform_set_create([uniform], shader, 0)


func _render_process(p_cursor: Vector2, p_blue: float) -> void:
	if rd == null or not pipeline.is_valid() or not uniform_set.is_valid():
		return

	# Must match the shader's Params block field for field: cursor, blue, padding (16 bytes)
	var bytes := PackedFloat32Array([
		p_cursor.x,
		p_cursor.y,
		p_blue,
		0.0
	]).to_byte_array()

	# Round up so partial groups at the edges are still covered (skip out-of-bounds pixels)
	@warning_ignore("integer_division")
	var x_groups := (size_rd.x -1) / GROUP_SIZE + 1
	@warning_ignore("integer_division")
	var y_groups := (size_rd.y -1) / GROUP_SIZE + 1

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, bytes, bytes.size())
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _free_compute_resources() -> void:
	if rd == null:
		return
	
	# Freeing the texture also frees the uniform_set
	if texture_rd.is_valid():
		rd.free_rid(texture_rd)
	
	# Freeing the shader also frees the pipeline
	if shader.is_valid():
		rd.free_rid(shader)

	# is_valid stays true after freeing, so reset the RIDs
	texture_rd = RID()
	uniform_set = RID()
	shader = RID()
	pipeline = RID()
