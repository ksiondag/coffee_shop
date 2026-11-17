extends Node

const FBO = preload("res://gpu/fbo.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")

var _dye: DoubleFBO
var _velocity: DoubleFBO
var _divergence: FBO
var _curl: FBO
var _pressure: DoubleFBO

var _size: Vector2

func _ready() -> void:
	_initialize(Vector2(512, 512))


func _initialize(size: Vector2) -> void:
	# TODO: Still filling this out
	return
	_size = size

	_dye = DoubleFBO.new(null, _size)
	_velocity = DoubleFBO.new(null, _size)
	_divergence = FBO.new(null, _size)
	_curl = FBO.new(null, _size)
	_pressure = DoubleFBO.new(null, _size)


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	pass
