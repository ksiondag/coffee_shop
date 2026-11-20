extends Node

const FBO = preload("res://gpu/fbo.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")


@export var fluid_fields: FluidFields


var _dye: DoubleFBO
var _velocity: DoubleFBO
var _divergence: FBO
var _curl: FBO
var _pressure: DoubleFBO


func _ready() -> void:
	pass


func initialize() -> void:
	_dye = fluid_fields.dye
	_velocity = fluid_fields.velocity
	_divergence = fluid_fields.divergence
	_curl = fluid_fields.curl
	_pressure = fluid_fields.pressure


func _process(delta: float) -> void:
	if not fluid_fields.initialized:
		return
	_step(delta)


func _step(delta: float) -> void:
	pass


func _on_view_resized(_size: Vector2) -> void:
	# TODO: There's a better way to do this initialize, but this works for now
	# Changing it later does not affect the overall implementation setup
	if _dye == null:
		initialize()
