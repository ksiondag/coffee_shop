class_name DoubleFBO extends GpuResources

const FBO = preload("res://gpu/fbo.gd")

var _size: Vector2
var _texture: Texture2DRD

var _read_index = 0

var _texture_rds: Array[RID] = [RID(), RID()];
var _uniform_rds: Array[RID] = [RID(), RID()];
var _uniform_set_rds: Array[RID] = [RID(), RID()];


func _init(size: Vector2):
	_size = size

	RenderingServer.call_on_render_thread(_initialize_texture)


func set_texture(texture: Texture2DRD) -> void:
	_texture = texture
	# TODO: Dirty to reuse _initialize_texture like this, need to set
	# texture_rd_rid in render thread?
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

	var index = 0
	while index < _texture_rds.size():
		if not _texture_rds[index].is_valid():
			_texture_rds[index] = FBO.create_texture(_size)
		index += 1

	if _texture != null:
		_texture.texture_rd_rid = _texture_rds[_read_index]


func swap() -> void:
	_read_index = (_read_index + 1) % _texture_rds.size()

	if _texture != null:
		_texture.texture_rd_rid = _texture_rds[_read_index]


func free() -> void:
	var index = 0
	while index < _texture_rds.size():
		if _texture_rds[index].is_valid():
			rd.free_rid(_texture_rds[index])
			_texture_rds[index] = RID()
		index += 1

	if _texture != null:
		_texture.texture_rd_rid = _texture_rds[_read_index]


func get_texture_rd() -> RID:
	return _texture_rds[_read_index]


func get_size() -> Vector2:
	return _size
