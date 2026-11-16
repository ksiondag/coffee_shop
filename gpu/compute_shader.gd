class_name ComputeShader extends RefCounted

# TODO: Should this be an abstract class?
# Each compute shader will have its own I/O that needs to be handled

# TODO: This is a magic variable that has to be set in two different places
# Must match local_size_x / local_size_y in the shader
const GROUP_SIZE := 8

# TODO: Texture output isn't always going to be the compute shader goal

# Need a good means of defining I/O as we want to and for this shared code to DTRT
# So, what I want to do here is have all GPU stuff live here and otherwise have
# an API elsewhere for handling the handoff between user action, Godot, and GPU
# work.

# I think a good next step is writing down each thing

var output: Texture2DRD


func _init(output_: Texture2DRD, texture_size: Vector2i, shader_path: String) -> void:
	# TODO: Need to handle when multiple shaders use the same texture
	# Doesn't matter for current use case, though the same texture will be
	# loaded multiple times
	# The fix, I believe, is our own reference counting system
	output = output_
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(texture_size, shader_path))


func free() -> void:
	# TODO: Wait, why are we doing this RID() thing here?
	if output:
		output.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_compute_resources)


func process(push_constant: PackedByteArray) -> void:
	if output and output.texture_rd_rid != texture_rd:
		output.texture_rd_rid = texture_rd

	RenderingServer.call_on_render_thread(_render_process.bind(push_constant))


# Rendering thread variables
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var texture_rd: RID
var uniform_set: RID
var size_rd: Vector2i


func _initialize_compute_code(size: Vector2i, shader_path: String) -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("Sim: no RenderingDevice. Compute shaders need Forward+ or Mobile running on Vulkan/D3D12/Metal")
		return

	var shader_file: RDShaderFile = load(shader_path)
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("Sim: %s failed to compile:\n%s" % [shader_path, spirv.compile_error_compute])
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)

	var tf = RDTextureFormat.new()
	# TODO: These are all options I would like to grok
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


func _render_process(push_constant: PackedByteArray) -> void:
	if rd == null or not pipeline.is_valid() or not uniform_set.is_valid():
		return

	# Round up so partial groups at the edges are still covered (skip out-of-bounds pixels)
	@warning_ignore("integer_division")
	var x_groups := (size_rd.x -1) / GROUP_SIZE + 1
	@warning_ignore("integer_division")
	var y_groups := (size_rd.y -1) / GROUP_SIZE + 1

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
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
