class_name FBO extends RefCounted

var _size: Vector2
var _texture: Texture2DRD

func _init(texture: Texture2DRD, size: Vector2):
	_size = size
	_texture = texture

	RenderingServer.call_on_render_thread(_initialize_texture)


# Rendering thread variables
var rd: RenderingDevice


func _initialize_texture() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("Sim: no RenderingDevice. Compute shaders need Forward+ or Mobile running on Vulkan/D3D12/Metal")
		return

	if _texture.texture_rd_rid.is_valid():
		push_error("Unexpected RID on texture: FBO will handle registering textures on GPU")
		return

	var tf = RDTextureFormat.new()
	# TODO: These are all options I would like to grok
	# DATA_FORMAT_R16G16B16A16_SFLOAT matches rgba16f in shader
	tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = _size.x
	tf.height = _size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	# TODO: Need to make this setable by calling code
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	_texture.texture_rd_rid = rd.texture_create(tf, RDTextureView.new(), [])


func free() -> void:
	if _texture.texture_rd_rid.is_valid():
		rd.free_rid(_texture.texture_rd_rid)
	_texture.texture_rd_rid = RID()


func uniform(binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(_texture.texture_rd_rid)
	return uniform

func get_size() -> Vector2:
	return _size
