class_name FBO extends RefCounted


var _size: Vector2
var _texture: Texture2DRD


func _init(size: Vector2):
	_size = size

	RenderingServer.call_on_render_thread(_initialize_texture)


func set_texture(texture: Texture2DRD) -> void:
	_texture = texture
	# TODO: Dirty to reuse _initialize_texture like this, need to set
	# texture_rd_rid in render thread
	RenderingServer.call_on_render_thread(_initialize_texture)


# Rendering thread variables
var rd: RenderingDevice
var _texture_rd: RID
var _initialized: bool


static func create_texture(size: Vector2) -> RID:
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("Sim: no RenderingDevice. Compute shaders need Forward+ or Mobile running on Vulkan/D3D12/Metal")
		return RID()
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
	# TODO: Need to make this setable by calling code
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	return rd.texture_create(tf, RDTextureView.new(), [])


func _initialize_texture() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("Sim: no RenderingDevice. Compute shaders need Forward+ or Mobile running on Vulkan/D3D12/Metal")
		return

	if _texture != null and _texture.texture_rd_rid.is_valid():
		_texture_rd = _texture.texture_rd_rid
		_initialized = false
		return

	if _texture_rd == null or not _texture_rd.is_valid():
		_texture_rd = create_texture(_size)

	if _texture:
		_texture.texture_rd_rid = _texture_rd

	_initialized = true


func free() -> void:
	if not _initialized:
		return
	if _texture_rd.is_valid():
		rd.free_rid(_texture_rd)
	_texture_rd = RID()
	if _texture != null:
		_texture.texture_rd_rid = _texture_rd


func uniform(binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(_texture_rd)
	return uniform


func get_size() -> Vector2:
	return _size
