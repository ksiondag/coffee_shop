extends Node


const ComputeShader = preload("res://gpu/compute_shader.gd")
const DoubleFBO = preload("res://gpu/double_fbo.gd")
const FluidFields = preload("res://fluid/fluid_fields.gd")
const GaussianSplat = preload("res://fluid/fluids2d/gaussian_splat.gd")

@export var fluid_fields: FluidFields

@export var output: Texture2DRD
@export var color: Color

# TODO:  radius should be pixel-size to be easier to reason on
@export var radius: float

# TODO: Numbers to play with to fine-tune (should be exports
# The pitcher velocity
@export var pitcher_velocity: float
# Pitcher angle (so not just straight down)
@export_range(0,360) var pitcher_angle: float

# Velocity radius to splat radius ratio
@export var velocity_dye_ratio: float

# Fluids2D conifg constants

var dye: DoubleFBO
var dye_splat: GaussianSplat

var velocity: DoubleFBO
var velocity_splat: GaussianSplat

var texture_size: Vector2i

var mouse_left_pressed: bool = false
var mouse_position: Vector2
func _input(event) -> void:
	if event.is_action_pressed("mouse_left"):
		mouse_left_pressed = true
		mouse_position = event.position
	elif event.is_action_released("mouse_left"):
		mouse_left_pressed = false
	elif event is InputEventMouseMotion:
		mouse_position = event.position


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if dye_splat != null:
		dye_splat.release()
	dye_splat = null
	if velocity_splat != null:
		velocity_splat.release()
	velocity_splat = null


func _velocity_from_scale_and_angle(scale: float, angle: float) -> Color:
	var angle_radian := angle * PI / 180
	return Color(
		scale * cos(angle_radian),
		scale * sin(angle_radian),
		0,
		0,
	)


func _process(delta: float) -> void:
	if mouse_left_pressed:
		if velocity_splat != null:
			velocity_splat.process(
				Vector2(mouse_position.x / velocity.get_size().x, mouse_position.y / velocity.get_size().y),
				_velocity_from_scale_and_angle(pitcher_velocity, pitcher_angle),
				radius,
				velocity.get_size().x / velocity.get_size().y
			)
		if dye_splat != null:
			dye_splat.process(
				Vector2(mouse_position.x / dye.get_size().x, mouse_position.y / dye.get_size().y),
				color,
				radius / velocity_dye_ratio,
				dye.get_size().x / dye.get_size().y
			)


func _on_view_resized(_size: Vector2) -> void:
	if dye == null && fluid_fields.initialized:
		dye = fluid_fields.dye
		dye.set_texture(output)
		dye_splat = GaussianSplat.new(dye)
	if velocity == null && fluid_fields.initialized:
		velocity = fluid_fields.velocity
		velocity_splat = GaussianSplat.new(velocity)
