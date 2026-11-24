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
	var velocity := fluid_fields.velocity
	var dye := fluid_fields.dye
	var curl := fluid_fields.curl
	var divergence := fluid_fields.divergence
	var pressure := fluid_fields.pressure

	_curl = Curl.new(velocity, curl)
	_vorticity = Vorticity.new(velocity, curl)
	_divergence = Divergence.new(velocity, divergence)
	_pressure_decay = PressureDecay.new(pressure)
	_pressure = Pressure.new(divergence, pressure)
	_gradient_subtract = GradientSubtract.new(pressure, velocity)
	_velocity_advection = Advection.new(velocity, velocity)
	_dye_advection = Advection.new(velocity, dye)


func _exit_tree() -> void:
	if _initialized:
		for fluid_pass in [
			_curl, _vorticity, _divergence, _pressure_decay, _pressure,
			_gradient_subtract, _velocity_advection, _dye_advection,
		]:
			fluid_pass.release()
		_initialized = false
	# Fluids2D owns the shared fields, so it frees them for every node using them
	fluid_fields.release()


func _process(delta: float) -> void:
	if not _initialized:
		return
	RenderingServer.call_on_render_thread(_step.bind(delta))


func _step(delta: float) -> void:
	_curl.process(delta)
	_vorticity.process(delta, fluid_fields.vorticity)
	_divergence.process(delta)
	_pressure_decay.process(delta, fluid_fields.pressure_decay)
	_pressure.process(delta, fluid_fields.pressure_iterations)
	_gradient_subtract.process(delta)

	# Velocity first, then dye carried by the new velocity
	_velocity_advection.process(delta, fluid_fields.velocity_dissipation)
	_dye_advection.process(delta, fluid_fields.dye_dissipation)


func _on_view_resized(_size: Vector2) -> void:
	# TODO: There's a better way to do this initialize, but this works for now
	# Changing it later does not affect the overall implementation setup
	if fluid_fields.initialized and not _initialized:
		initialize()
