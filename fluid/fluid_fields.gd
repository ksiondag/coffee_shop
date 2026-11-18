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


func initialize(size: Vector2) -> void:
	print(size)
	# TODO: Still filling this out
	initialized = true
	size = size

	dye = DoubleFBO.new(null, size)
	velocity = DoubleFBO.new(null, size)
	divergence = FBO.new(null, size)
	curl = FBO.new(null, size)
	pressure = DoubleFBO.new(null, size)
