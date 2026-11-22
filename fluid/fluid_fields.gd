class_name FluidFields extends Resource

const FBO = preload("res://gpu/fbo.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")

var initialized: bool = false

var dye: DoubleFBO
var velocity: DoubleFBO
var divergence: FBO
var curl: FBO
var pressure: DoubleFBO

var size: Vector2 = Vector2(0, 0)


# size is the simulation resolution
# dye_size defaults to the same size; it can be larger
func initialize(size: Vector2, dye_size: Vector2 = Vector2.ZERO) -> void:
	# Fields are created once; resizing them is not supported yet
	if initialized:
		return
	initialized = true
	self.size = size
	if dye_size == Vector2.ZERO:
		dye_size = size

	dye = DoubleFBO.new(dye_size)
	velocity = DoubleFBO.new(size)
	divergence = FBO.new(size)
	curl = FBO.new(size)
	pressure = DoubleFBO.new(size)


# New textures are not guaranteed to start at zero, so clear every texture.
# Queued on the render thread after the textures are created.
func clear_to_zero() -> void:
	RenderingServer.call_on_render_thread(_clear_to_zero)


func _clear_to_zero() -> void:
	var rd := RenderingServer.get_rendering_device()
	for double_fbo: DoubleFBO in [dye, velocity, pressure]:
		var zero := _zero_bytes(double_fbo.get_size())
		rd.texture_update(double_fbo.get_texture_rd(), 0, zero)
		rd.texture_update(double_fbo.get_write_texture_rd(), 0, zero)
	for fbo: FBO in [divergence, curl]:
		rd.texture_update(fbo.get_texture_rd(), 0, _zero_bytes(fbo.get_size()))


func _zero_bytes(texture_size: Vector2) -> PackedByteArray:
	# Image.create starts zero-filled; RGBAH matches DATA_FORMAT_R16G16B16A16_SFLOAT
	return Image.create(int(texture_size.x), int(texture_size.y), false, Image.FORMAT_RGBAH).get_data()


func release() -> void:
	if not initialized:
		return
	dye.release()
	velocity.release()
	divergence.release()
	curl.release()
	pressure.release()
	dye = null
	velocity = null
	divergence = null
	curl = null
	pressure = null
	initialized = false
