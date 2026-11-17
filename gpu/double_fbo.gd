class_name DoubleFBO extends RefCounted

const FBO = preload("res://gpu/fbo.gd")

var _size: Vector2
var _texture: Texture2DRD

var _read: RID
var _write: RID

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

	if _texture != null and _texture.texture_rd_rid.is_valid():
		push_error("Unexpected RID on texture: FBO will handle registering textures on GPU")
		return

	_read = FBO.create_texture(_size)
	_write = FBO.create_texture(_size)
	if _texture != null:
		_texture.texture_rd_rid = _read


func free() -> void:
	if _texture.texture_rd_rid.is_valid():
		rd.free_rid(_texture.texture_rd_rid)
	if _texture != null:
		_texture.texture_rd_rid = RID()


func uniform(binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(_texture.texture_rd_rid)
	return uniform

func get_size() -> Vector2:
	return _size
