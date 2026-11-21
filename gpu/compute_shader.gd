@abstract class_name ComputeShader extends RefCounted

const GPUResources = preload("res://gpu/gpu_resources.gd")

# TODO: Should this be an abstract class?
# Each compute shader will have its own I/O that needs to be handled

# TODO: This is a magic variable that has to be set in two different places
# Must match local_size_x / local_size_y in the shader
const GROUP_SIZE := 8


var _output: GPUResources


func _init(output: GPUResources, shader_path: String) -> void:
	_output = output
	RenderingServer.call_on_render_thread(_initialize_compute_code.bind(shader_path))


func free() -> void:
	RenderingServer.call_on_render_thread(_free_compute_resources)


func process(push_constants: PackedByteArray) -> void:
	RenderingServer.call_on_render_thread(_render_process.bind(push_constants))


# Rendering thread variables and functions
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID


@abstract func set_uniform_sets(rd: RenderingDevice, shader: RID, compute_list: int) -> void


func _initialize_compute_code(shader_path: String) -> void:
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


func _render_process(push_constants: PackedByteArray) -> void:
	if rd == null or not pipeline.is_valid():
		return

	# Round up so partial groups at the edges are still covered (skip out-of-bounds pixels)
	@warning_ignore("integer_division")
	var x_groups := (_output.get_size().x -1) / GROUP_SIZE + 1
	@warning_ignore("integer_division")
	var y_groups := (_output.get_size().y -1) / GROUP_SIZE + 1

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

	# After these functions exist, delete below
	set_uniform_sets(rd, shader, compute_list)

	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _free_compute_resources() -> void:
	if rd == null:
		return

	# Freeing the shader also frees the pipeline
	if shader.is_valid():
		rd.free_rid(shader)

	# is_valid stays true after freeing, so reset the RIDs
	uniform_set = RID()
	shader = RID()
	pipeline = RID()
