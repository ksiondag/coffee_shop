extends Control

# Sets up the sim like Unity's Fluids2D.Start (128 sim / 1024 dye), then plays
# back the recording. Calls down: creates the fields and hands them to children.

const FluidFields = preload("res://fluid/fluid_fields.gd")

# TODO: These are config values (SIM_RESOLUTION / DYE_RESOLUTION)
@export var sim_resolution: int = 128
@export var dye_resolution: int = 1024

@onready var _view: TextureRect = $View
@onready var _playback: Node = $Playback
@onready var _fluids2d: Node = $Fluids2D


func _ready() -> void:
	var fields := FluidFields.new()
	fields.initialize(
		Vector2(sim_resolution, sim_resolution), Vector2(dye_resolution, dye_resolution)
	)
	fields.clear_to_zero()
	fields.dye.set_texture(_view.texture)

	# Fluids2D owns the fields and releases them on exit
	_fluids2d.fluid_fields = fields
	_fluids2d.initialize()
	_playback.initialize(fields)
