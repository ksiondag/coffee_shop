extends Node

# Replays a Recording of pourer input
# This is to verify the port from the Unity project is basically identical
# Must sit above Fluids2D in the scene tree: _process runs in tree order, so
# this frame's splats are queued on the render thread before this frame's step,
# matching Unity's ApplyInputs-then-Step.

const FluidFields = preload("res://fluid/fluid_fields.gd")
const GaussianSplat = preload("res://fluid/fluids2d/gaussian_splat.gd")

@export var recording: Recording

# TODO: These are config values (SPLAT_FORCE / SPLAT_RADIUS)
@export var splat_force: float = 6000.0
@export var splat_radius: float = 0.15
# Pourer color in the Unity scene
@export var color: Color = Color(1, 1, 1, 0)

var _velocity_splat: GaussianSplat
var _dye_splat: GaussianSplat

var _row: int = 0
var _current_time: float = 0.0
var _trigger_input_time: float = 0.0


func initialize(fluid_fields: FluidFields) -> void:
	_velocity_splat = GaussianSplat.new(fluid_fields.velocity)
	_dye_splat = GaussianSplat.new(fluid_fields.dye)
	_row = 0
	_current_time = 0.0
	_trigger_input_time = recording.get_dt(_row)


func _process(delta: float) -> void:
	if _velocity_splat == null:
		return

	# Like Unity: real frame time, at most one row per frame, loop forever
	_current_time += delta
	if _current_time > _trigger_input_time:
		var point := recording.get_coord(_row)
		var force := recording.get_delta(_row) * splat_force
		RenderingServer.call_on_render_thread(_splat.bind(point, force))

		_row = (_row + 1) % recording.row_count()
		_trigger_input_time += recording.get_dt(_row)


func _splat(point: Vector2, force: Vector2) -> void:
	var radius := splat_radius / 100.0
	_velocity_splat.process(point, Color(force.x, force.y, 0.0, 0.0), radius)
	_dye_splat.process(point, Color(color.r, color.g, color.b, 0.0), radius / 10.0)


func _exit_tree() -> void:
	if _velocity_splat != null:
		_velocity_splat.release()
		_dye_splat.release()
	_velocity_splat = null
	_dye_splat = null
