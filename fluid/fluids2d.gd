extends Node

const FBO = preload("res://gpu/fbo.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")


@export var fluid_fields: FluidFields


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	pass
