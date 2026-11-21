extends Node

const FluidFields = preload("res://fluid/fluid_fields.gd")
const Curl = preload("res://fluid/fluids2d/curl.gd")

@export var fluid_fields: FluidFields

var _initialized: bool = false

var _curl: Curl


func _ready() -> void:
	pass


func initialize() -> void:
	_initialized = true
	_curl = Curl.new(fluid_fields)


func _process(delta: float) -> void:
	if not _initialized:
		return
	_step(delta)


func _step(delta: float) -> void:
	_curl.process(delta)


func _on_view_resized(_size: Vector2) -> void:
	# TODO: There's a better way to do this initialize, but this works for now
	# Changing it later does not affect the overall implementation setup
	if fluid_fields.initialized and not _initialized:
		initialize()
