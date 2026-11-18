class_name FluidFields extends Resource

const FBO = preload("res://gpu/fbo.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")

var initialized: bool = false

# TODO: This will be a double fbo once we have everything in place
var dye: FBO
var velocity: DoubleFBO
var divergence: FBO
var curl: FBO
var pressure: DoubleFBO

var size: Vector2 = Vector2(0, 0)


func initialize(size: Vector2) -> void:
	initialized = true
	size = size

	dye = FBO.new(null, size)
	velocity = DoubleFBO.new(null, size)
	divergence = FBO.new(null, size)
	curl = FBO.new(null, size)
	pressure = DoubleFBO.new(null, size)
