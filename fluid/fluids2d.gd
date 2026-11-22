extends Node

const FluidFields = preload("res://fluid/fluid_fields.gd")
const Curl = preload("res://fluid/fluids2d/curl.gd")
const Vorticity = preload("res://fluid/fluids2d/vorticity.gd")
const Divergence = preload("res://fluid/fluids2d/divergence.gd")
const PressureDecay = preload("res://fluid/fluids2d/pressure_decay.gd")
const Pressure = preload("res://fluid/fluids2d/pressure.gd")
const GradientSubtract = preload("res://fluid/fluids2d/gradient_subtract.gd")
const Advection = preload("res://fluid/fluids2d/advection.gd")

@export var fluid_fields: FluidFields

var _initialized: bool = false

var _curl: Curl
var _vorticity: Vorticity
var _divergence: Divergence
var _pressure_decay: PressureDecay
var _pressure: Pressure
var _gradient_subtract: GradientSubtract
var _velocity_advection: Advection
var _dye_advection: Advection


func _ready() -> void:
	pass


func initialize() -> void:
	_initialized = true
	_curl = Curl.new(fluid_fields)
	_vorticity = Vorticity.new(fluid_fields)
	_divergence = Divergence.new(fluid_fields)
	_pressure_decay = PressureDecay.new(fluid_fields)
	_pressure = Pressure.new(fluid_fields)
	_gradient_subtract = GradientSubtract.new(fluid_fields)
	_velocity_advection = Advection.new(
		fluid_fields, fluid_fields.velocity, Advection.VELOCITY_DISSIPATION
	)
	_dye_advection = Advection.new(fluid_fields, fluid_fields.dye, Advection.DYE_DISSIPATION)


func _process(delta: float) -> void:
	if not _initialized:
		return
	RenderingServer.call_on_render_thread(_step.bind(delta))


func _step(delta: float) -> void:
	_curl.process(delta)
	_vorticity.process(delta)
	_divergence.process(delta)
	_pressure_decay.process(delta)
	_pressure.process(delta)
	_gradient_subtract.process(delta)

	# Velocity first, then dye carried by the new velocity
	_velocity_advection.process(delta)
	_dye_advection.process(delta)


func _on_view_resized(_size: Vector2) -> void:
	# TODO: There's a better way to do this initialize, but this works for now
	# Changing it later does not affect the overall implementation setup
	if fluid_fields.initialized and not _initialized:
		initialize()
